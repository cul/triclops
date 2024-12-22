class Resource < ApplicationRecord
  include Triclops::Resource::IiifInfo
  include Triclops::Resource::AsJson
  include Triclops::Resource::Validations

  PCDM_TEXT_TYPES = [
    BestType::PcdmTypeLookup::EMAIL, BestType::PcdmTypeLookup::PAGE_DESCRIPTION, BestType::PcdmTypeLookup::STRUCTURED_TEXT,
    BestType::PcdmTypeLookup::TEXT, BestType::PcdmTypeLookup::UNSTRUCTURED_TEXT
  ].freeze

  enum status: { pending: 0, processing: 1, failure: 2, ready: 3 }

  before_validation :wait_for_source_uri_if_local_disk_file
  before_save :switch_to_pending_state_if_core_properties_changed!
  after_save :queue_base_derivative_generation_if_pending
  after_destroy :delete_filesystem_cache!

  def wait_for_source_uri_if_local_disk_file
    return if self.source_uri.nil? || !self.source_uri.start_with?('file:/')
    file_path = Triclops::Utils::UriUtils.location_uri_to_file_path(self.source_uri)

    # Under certain circumstances, a source_uri file that was recently writter by an external
    # process may take a few seconds to become available for reading (for example, if the file
    # was written to a network disk and the change has not been propagated yet to other servers).
    # So we'll wait and try again a few times, if it's not found right away.
    5.times do
      break if File.exist?(file_path)
      sleep 1
    end
  end

  # Generates a placeholder resource dynamically (without any database interaction),
  # based on the given placeholder_resource_identifier.  Note that this method
  # will raise an exception if placeholder_resource_identifier is not a
  # recognized placeholder identifier.
  def self.placeholder_resource_for(placeholder_resource_identifier)
    raise ArgumentError unless KNOWN_PLACEHOLDER_IDENTIFIERS.include?(placeholder_resource_identifier)
    Resource.new(
      identifier: placeholder_resource_identifier,
      has_view_limitation: false,
      status: 'ready',
      updated_at: Time.current,
      source_uri: placeholder_resource_identifier.sub(':', ':///'),
      standard_width: PLACEHOLDER_SIZE,
      standard_height: PLACEHOLDER_SIZE,
      limited_width: Triclops::Iiif::Constants::LIMITED_BASE_SIZE,
      limited_height: Triclops::Iiif::Constants::LIMITED_BASE_SIZE,
      featured_width: Triclops::Iiif::Constants::FEATURED_BASE_SIZE,
      featured_height: Triclops::Iiif::Constants::FEATURED_BASE_SIZE,
      featured_region: "0,0,#{PLACEHOLDER_SIZE},#{PLACEHOLDER_SIZE}"
    )
  end

  # Clear ALL cached image files for this resource.
  def delete_filesystem_cache!
    FileUtils.rm_rf(Triclops::RasterCache.instance.cache_directory_for_identifier(self.identifier))
  end

  def queue_base_derivative_generation_if_pending
    return unless self.pending?
    CreateBaseDerivativesJob.perform_later(self.identifier)
  end

  def raise_exception_if_base_derivative_dependency_missing!
    missing_fields = []
    missing_fields << 'source_uri' if self.source_uri.nil?
    missing_fields << 'featured_region' if self.featured_region.nil?

    return if missing_fields.empty?

    raise Triclops::Exceptions::MissingBaseImageDependencyException,
          "Cannot generate base derivatives for #{self.identifier} because the following required fields are nil: " +
          missing_fields.join(', ')
  end

  # Generates base derivatives
  # rubocop:disable Metrics/AbcSize
  def generate_base_derivatives_if_not_exist!
    raise_exception_if_base_derivative_dependency_missing!
    standard_base_path = Triclops::RasterCache.instance.base_cache_path(Triclops::Iiif::Constants::BASE_TYPE_STANDARD, self.identifier, mkdir_p: true)
    limited_base_path = Triclops::RasterCache.instance.base_cache_path(Triclops::Iiif::Constants::BASE_TYPE_LIMITED, self.identifier, mkdir_p: true)
    featured_base_path = Triclops::RasterCache.instance.base_cache_path(Triclops::Iiif::Constants::BASE_TYPE_FEATURED, self.identifier, mkdir_p: true)

    return if File.exist?(standard_base_path) && File.exist?(limited_base_path) && File.exist?(featured_base_path)

    self.with_source_image_file do |source_image_file|
      # Use the original image to generate standard base
      unless File.exist?(standard_base_path)
        Triclops::Raster.generate(
          source_image_file.path,
          standard_base_path,
          {
            region: 'full',
            size: 'full',
            rotation: 0,
            quality: Triclops::Iiif::Constants::BASE_QUALITY,
            format: Triclops::Iiif::Constants::BASE_IMAGE_FORMAT
          }
        )
      end
      # Store standard base dimensions
      # NOTE: Must use `revalidate: true` option below to avoid relying on underlying vips recent operation cache.
      Imogen.with_image(standard_base_path, { revalidate: true }) do |img|
        self.standard_width = img.width
        self.standard_height = img.height
      end

      # Use the original image to generate the limited base
      # Note: Technically the 'limited' base can be larger than the source image, if the source image
      # has a long side that's smaller than LIMITED_BASE_SIZE.  But that case will be rare, and
      # shouldn't cause any issues.
      unless File.exist?(limited_base_path)
        Triclops::Raster.generate(
          source_image_file.path,
          limited_base_path,
          {
            region: 'full',
            size: "!#{Triclops::Iiif::Constants::LIMITED_BASE_SIZE},#{Triclops::Iiif::Constants::LIMITED_BASE_SIZE}",
            rotation: 0,
            quality: Triclops::Iiif::Constants::BASE_QUALITY,
            format: Triclops::Iiif::Constants::BASE_IMAGE_FORMAT
          }
        )
      end
      # Store limited base dimensions
      # NOTE: Must use `revalidate: true` option below to avoid relying on underlying vips recent operation cache.
      Imogen.with_image(limited_base_path, { revalidate: true }) do |img|
        self.limited_width = img.width
        self.limited_height = img.height
      end

      # Use the original image to generate the featured base
      # Note: Technically the 'featured' base can be larger than the standard base, if the standard base
      # has a long side that's smaller than FEATURED_BASE_SIZE.  But that case will be rare, and
      # shouldn't cause any issues.

      unless File.exist?(featured_base_path)
        Triclops::Raster.generate(
          source_image_file.path,
          featured_base_path,
          {
            region: self.featured_region,
            size: "!#{Triclops::Iiif::Constants::FEATURED_BASE_SIZE},#{Triclops::Iiif::Constants::FEATURED_BASE_SIZE}",
            rotation: 0,
            quality: Triclops::Iiif::Constants::BASE_QUALITY,
            format: Triclops::Iiif::Constants::BASE_IMAGE_FORMAT
          }
        )
      end

      # Store featured base dimensions
      # NOTE: Must use `revalidate: true` option below to avoid relying on underlying vips recent operation cache.
      Imogen.with_image(featured_base_path, { revalidate: true }) do |img|
        self.featured_width = img.width
        self.featured_height = img.height
      end
    end

    # Save so that width/height, limited_width/limited_height, featured_width/featured_height properties are persisted.
    self.save!

    true
  end
  # rubocop:enable Metrics/AbcSize

  # Generates commonly requested standard, reduced, and featured derivatives.
  def generate_commonly_requested_derivatives
    generate_base_derivatives_if_not_exist!

    self.generate_commonly_requested_standard_derivatives
    self.generate_commonly_requested_limited_derivatives
    self.generate_commonly_requested_featured_derivatives
  end

  # Generates the following "standard" derivatives:
  # - Scaled versions at Triclops::Iiif::Constants::RECOMMENDED_SIZES.
  # - IIIF zooming image viewer tiles
  def generate_commonly_requested_standard_derivatives
    standard_base_path = Triclops::RasterCache.instance.base_cache_path(Triclops::Iiif::Constants::BASE_TYPE_STANDARD, self.identifier)

    # Generate scaled rasters at Triclops::Iiif::Constants::RECOMMENDED_SIZES.
    Triclops::Iiif::Constants::RECOMMENDED_SIZES.each do |size|
      raster_opts = {
        region: 'full',
        size: "!#{size},#{size}",
        rotation: 0,
        quality: Triclops::Iiif::Constants::BASE_QUALITY,
        format: Triclops::Iiif::Constants::DEFAULT_FORMAT
      }
      raster_path = Triclops::RasterCache.instance.iiif_cache_path_for_raster(
        Triclops::Iiif::Constants::BASE_TYPE_STANDARD,
        self.identifier,
        raster_opts,
        mkdir_p: true
      )
      next if File.exist?(raster_path)

      Triclops::Raster.generate(
        standard_base_path,
        raster_path,
        raster_opts
      )
    end

    # Generate IIIF zooming image viewer tiles
    Imogen.with_image(standard_base_path, { revalidate: true }) do |image|
      Imogen::Iiif::Tiles.for(
        image,
        Triclops::RasterCache.instance.iiif_cache_directory_for_identifier(
          Triclops::Iiif::Constants::BASE_TYPE_STANDARD,
          self.identifier
        ),
        :jpg,
        Triclops::Iiif::Constants::TILE_SIZE,
        'color'
      ) do |img, suggested_tile_dest_path, format, iiif_opts|
        FileUtils.mkdir_p(File.dirname(suggested_tile_dest_path))
        Imogen::Iiif.convert(img, suggested_tile_dest_path, format, iiif_opts)
      end
    end
    # If the Imogen::Iiif::Tiles.generate_with_vips_dzsave method were fully implemented,
    # we would call it like this:
    # Imogen.with_image(standard_base_path, { revalidate: true }) do |image|
    #   Imogen::Iiif::Tiles.generate_with_vips_dzsave(
    #     image,
    #     Triclops::RasterCache.instance.iiif_cache_directory_for_identifier(self.identifier),
    #     format: :jpg,
    #     tile_size: Triclops::Iiif::Constants::TILE_SIZE,
    #     tile_filename_without_extension: 'color'
    #   )
    # end

    true
  end

  # Generates the following "limited" derivatives:
  # - Scaled versions at Triclops::Iiif::Constants::RECOMMENDED_LIMITED_SIZES.
  # - IIIF zooming image viewer tiles
  def generate_commonly_requested_limited_derivatives
    limited_base_path = Triclops::RasterCache.instance.base_cache_path(Triclops::Iiif::Constants::BASE_TYPE_LIMITED, self.identifier)

    # Generate scaled rasters at Triclops::Iiif::Constants::RECOMMENDED_LIMITED_SIZES.
    Triclops::Iiif::Constants::RECOMMENDED_LIMITED_SIZES.each do |size|
      raster_opts = {
        region: 'full',
        size: "!#{size},#{size}",
        rotation: 0,
        quality: Triclops::Iiif::Constants::BASE_QUALITY,
        format: Triclops::Iiif::Constants::DEFAULT_FORMAT
      }
      raster_path = Triclops::RasterCache.instance.iiif_cache_path_for_raster(
        Triclops::Iiif::Constants::BASE_TYPE_LIMITED,
        self.identifier,
        raster_opts,
        mkdir_p: true
      )
      next if File.exist?(raster_path)

      Triclops::Raster.generate(
        limited_base_path,
        raster_path,
        raster_opts
      )
    end

    # Generate IIIF zooming image viewer tiles
    Imogen.with_image(limited_base_path, { revalidate: true }) do |image|
      Imogen::Iiif::Tiles.for(
        image,
        Triclops::RasterCache.instance.iiif_cache_directory_for_identifier(
          Triclops::Iiif::Constants::BASE_TYPE_LIMITED,
          self.identifier
        ),
        :jpg,
        Triclops::Iiif::Constants::TILE_SIZE,
        'color'
      ) do |img, suggested_tile_dest_path, format, iiif_opts|
        FileUtils.mkdir_p(File.dirname(suggested_tile_dest_path))
        Imogen::Iiif.convert(img, suggested_tile_dest_path, format, iiif_opts)
      end
    end
  end

  # Generates the following "featured" derivatives:
  # - Scaled versions, at Triclops::Iiif::Constants::PRE_GENERATED_SQUARE_SIZES.
  def generate_commonly_requested_featured_derivatives
    featured_base_path = Triclops::RasterCache.instance.base_cache_path(Triclops::Iiif::Constants::BASE_TYPE_FEATURED, self.identifier)

    # Generate recommended featured versions at PRE_GENERATED_SQUARE_SIZES
    Triclops::Iiif::Constants::PRE_GENERATED_SQUARE_SIZES.each do |size|
      raster_opts = {
        region: 'full',
        size: "!#{size},#{size}",
        rotation: 0,
        quality: Triclops::Iiif::Constants::BASE_QUALITY,
        format: Triclops::Iiif::Constants::DEFAULT_FORMAT
      }
      raster_path = Triclops::RasterCache.instance.iiif_cache_path_for_raster(
        Triclops::Iiif::Constants::BASE_TYPE_FEATURED,
        self.identifier,
        raster_opts,
        mkdir_p: true
      )
      next if File.exist?(raster_path)

      Triclops::Raster.generate(
        featured_base_path,
        raster_path,
        raster_opts
      )
    end

    true
  end

  # Returns an array of scale factors (e.g. [1, 2, 4, 8, 16]), based on the image dimensions
  # and the given tile_size.
  def scale_factors_for_tile_size(width, height, tile_size)
    Imogen::Iiif::Tiles.scale_factors_for(width, height, tile_size)
  end

  # Certain property changes should will trigger a switch to the pending state (which will trigger base
  # derivative regeneration).
  def switch_to_pending_state_if_core_properties_changed!
    return if new_record?
    return unless self.source_uri_changed? || self.featured_region_changed? || self.pcdm_type_changed?

    self.status = :pending
  end

  # Yields a block with a File reference to the source image file for this Resource.
  #
  # @api private
  # @yield source_image_file [File] A file holding the source image content.
  def with_source_image_file
    raise Errno::ENOENT, 'Missing source_uri' if self.source_uri.blank?
    uri_scheme = Addressable::URI.parse(self.source_uri).scheme

    if ['file', 'railsroot', 'placeholder'].include?(uri_scheme)
      yield File.new(Triclops::Utils::UriUtils.location_uri_to_file_path(self.source_uri))
      return
    end

    raise Errno::ENOENT, "Could not resolve file location: #{self.source_uri}"
  end

  # @api private
  def source_uri_is_readable?
    return false if source_uri.blank?
    with_source_image_file do |file|
      return File.readable?(file)
    end
  rescue Errno::ENOENT
    false
  end

  # Yields a block with a File reference to the specified raster.
  # @param raster_opts [Hash]
  #   A hash of IIIF options (e.g. {region: '...', size: '...', etc. }).
  # @param cache_enabled [boolean]
  #   If true, serves a cached version of the raster (when available) or
  #   generates and caches a new raster.  If false, always generates a new
  #   raster and does not cache that new raster.
  #
  # @yield raster_file [File] A file reference to the specified raster.
  # @return [void]
  # def raster(raster_opts, cache_enabled: false)
  #   if cache_enabled
  #     yield_cached_raster(base_type, raster_opts) { |raster_file| yield raster_file }
  #   else
  #     yield_uncached_raster(base_type, raster_opts) { |raster_file| yield raster_file }
  #   end
  # end

  def raster_exists?(base_type, raster_opts)
    File.exist?(iiif_cache_path_for_raster(base_type, raster_opts))
  end

  # Uses this Resource's pcdm_type value to determine which placeholder identifier should be returned
  def placeholder_identifier_for_pcdm_type
    case self.pcdm_type
    when BestType::PcdmTypeLookup::AUDIO
      'placeholder:sound'
    when BestType::PcdmTypeLookup::VIDEO
      'placeholder:moving_image'
    when *PCDM_TEXT_TYPES
      'placeholder:text'
    when BestType::PcdmTypeLookup::SOFTWARE
      'placeholder:software'
    else
      'placeholder:unavailable'
    end
  end

  # @api private
  def iiif_cache_path_for_raster(base_type, raster_opts)
    Triclops::RasterCache.instance.iiif_cache_path_for_raster(
      base_type,
      source_uri_is_placeholder? ? self.source_uri : self.identifier,
      raster_opts
    )
  end

  # @api private
  def yield_cached_raster(base_type, raster_opts)
    # Get cache path
    raster_file_path = iiif_cache_path_for_raster(base_type, raster_opts)

    unless File.exist?(raster_file_path)
      # We use a blocking lock so that two processes don't try to to run the
      # same file creation operation at the same time.
      Triclops::Lock.instance.with_blocking_lock(raster_file_path) do
        # We do a second File.exists? check inside of the lock to ensure
        # that file generation does not occur if the file was created
        # while waiting to establish this lock.
        unless File.exist?(raster_file_path)
          FileUtils.mkdir_p(File.dirname(raster_file_path))
          self.with_source_image_file do |source_image_file|
            Triclops::Raster.generate(source_image_file.path, raster_file_path, raster_opts)
          end
        end
      end
    end

    yield File.new(raster_file_path)
  end

  # @api private
  def yield_uncached_raster(raster_opts)
    raster_tempfile_path = self.class.generate_raster_tempfile_path(raster_opts[:format])
    FileUtils.mkdir_p(File.dirname(raster_tempfile_path))
    self.with_source_image_file do |source_image_file|
      Triclops::Raster.generate(source_image_file.path, raster_tempfile_path, raster_opts)
    end
    temp_file = File.new(raster_tempfile_path)
    yield temp_file
  ensure
    # Close file if it's open and then unlink the file.
    if temp_file
      temp_file.close unless temp_file.closed?
      File.unlink(temp_file)
    end
  end

  # Returns true if this Resource's source_uri points to a placeholder image value.
  #
  # @api private
  # @return [Boolean] true if source_uri starts with 'placeholder:///'
  def source_uri_is_placeholder?
    return false if self.source_uri.nil?
    self.source_uri.start_with?('placeholder:///')
  end

  def self.generate_raster_tempfile_path(extension = '.blob')
    loop do
      # Generate unique temp raster in temp location
      raster_tempfile_path = File.join(TRICLOPS[:tmp_directory], "#{Rails.application.class.module_parent_name.underscore}-tmp-#{SecureRandom.uuid}.#{extension}")
      return raster_tempfile_path unless File.exist?(raster_tempfile_path)
    end
  end
end
