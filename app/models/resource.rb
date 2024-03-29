class Resource < ApplicationRecord
  include Triclops::Resource::IiifInfo
  include Triclops::Resource::AsJson
  include Triclops::Resource::Validations

  PCDM_TEXT_TYPES = [
    BestType::PcdmTypeLookup::EMAIL, BestType::PcdmTypeLookup::PAGE_DESCRIPTION, BestType::PcdmTypeLookup::STRUCTURED_TEXT,
    BestType::PcdmTypeLookup::TEXT, BestType::PcdmTypeLookup::UNSTRUCTURED_TEXT
  ].freeze

  enum status: { pending: 0, processing: 1, failure: 2, ready: 3 }

  before_validation :extract_width_and_height_if_missing_or_source_changed!
  after_save :queue_base_derivative_generation_if_pending
  after_destroy :delete_filesystem_cache!

  # Generates a placeholder resource dynamically (without any database interaction)
  def self.placeholder_resource_for(identifier)
    Resource.new(
      identifier: identifier,
      status: 'ready',
      updated_at: Time.current,
      source_uri: identifier.sub(':', '://'),
      width: PLACEHOLDER_SIZE,
      height: PLACEHOLDER_SIZE,
      featured_region: "0,0,#{PLACEHOLDER_SIZE},#{PLACEHOLDER_SIZE}"
    )
  end

  # Clear ALL cached image files for this resource.
  def delete_filesystem_cache!
    FileUtils.rm_rf(Triclops::RasterCache.instance.cache_directory_for_identifier(self.identifier))
  end

  def queue_base_derivative_generation_if_pending
    return unless self.pending? && self.source_uri.present?
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
  def generate_base_derivatives
    raise_exception_if_base_derivative_dependency_missing!

    # Generate full base at original resolution
    full_base_path = Triclops::RasterCache.instance.full_base_cache_path(self.identifier, mkdir_p: true)
    unless File.exist?(full_base_path)
      self.with_source_image_file do |source_image_file|
        Triclops::Raster.generate(
          source_image_file.path,
          full_base_path,
          {
            region: 'full',
            size: 'full',
            rotation: 0,
            quality: Triclops::Iiif::Constants::BASE_QUALITY,
            format: Triclops::Iiif::Constants::BASE_IMAGE_FORMAT
          }
        )
      end
    end

    # Use full base to generate reduced base
    # Note: Technically the 'reduced' base can be larger than the full base, if the full base
    # has a long side that's smaller than REDUCED_BASE_SIZE.  But that case will be rare, and
    # shouldn't cause any issues.
    reduced_base_path = Triclops::RasterCache.instance.reduced_base_cache_path(self.identifier, mkdir_p: true)
    unless File.exist?(reduced_base_path)
      Triclops::Raster.generate(
        full_base_path,
        reduced_base_path,
        {
          region: 'full',
          size: "!#{Triclops::Iiif::Constants::REDUCED_BASE_SIZE},#{Triclops::Iiif::Constants::REDUCED_BASE_SIZE}",
          rotation: 0,
          quality: Triclops::Iiif::Constants::BASE_QUALITY,
          format: Triclops::Iiif::Constants::BASE_IMAGE_FORMAT
        }
      )
    end

    true
  end

  def base_derivatives_exist?
    [
      Triclops::RasterCache.instance.full_base_cache_path(self.identifier),
      Triclops::RasterCache.instance.reduced_base_cache_path(self.identifier)
    ].each do |path|
      return false unless File.exist?(path)
    end
    true
  end

  # Generates commonly requested derivtives, including:
  # - Full region scaled versions of the original, at RECOMMENDED_SIZES
  # - (todo) IIIF zooming image viewer tiles
  # rubocop:disable Metrics/AbcSize
  def generate_commonly_requested_derivatives
    # Generate base derivatives if they don't already exist?
    generate_base_derivatives unless self.base_derivatives_exist?

    full_base_path = Triclops::RasterCache.instance.full_base_cache_path(self.identifier)

    # Generate recommended rasters at recommended sizes
    # with Triclops::Iiif::Constants::BASE_QUALITY quality
    # and Triclops::Iiif::Constants::DEFAULT_FORMAT format.
    Triclops::Iiif::Constants::RECOMMENDED_SIZES.each do |size|
      raster_opts = {
        region: 'full',
        size: "!#{size},#{size}",
        rotation: 0,
        quality: Triclops::Iiif::Constants::BASE_QUALITY,
        format: Triclops::Iiif::Constants::DEFAULT_FORMAT
      }
      iiif_cache_path = Triclops::RasterCache.instance.iiif_cache_path(
        self.identifier,
        raster_opts,
        mkdir_p: true
      )
      next if File.exist?(iiif_cache_path)

      Triclops::Raster.generate(
        full_base_path,
        iiif_cache_path,
        raster_opts
      )
    end

    # Generate recommended square versions at recommended sizes
    # with Triclops::Iiif::Constants::BASE_QUALITY quality
    # and Triclops::Iiif::Constants::DEFAULT_FORMAT format.
    Triclops::Iiif::Constants::PRE_GENERATED_SQUARE_SIZES.each do |size|
      raster_opts = {
        region: self.featured_region,
        size: "!#{size},#{size}",
        rotation: 0,
        quality: Triclops::Iiif::Constants::BASE_QUALITY,
        format: Triclops::Iiif::Constants::DEFAULT_FORMAT
      }
      iiif_cache_path = Triclops::RasterCache.instance.iiif_cache_path(
        self.identifier,
        raster_opts,
        mkdir_p: true
      )
      next if File.exist?(iiif_cache_path)

      Triclops::Raster.generate(
        full_base_path,
        iiif_cache_path,
        raster_opts
      )
    end

    # Generate IIIF zooming image viewer tiles

    Imogen.with_image(full_base_path, { revalidate: true }) do |image|
      Imogen::Iiif::Tiles.for(
        image,
        Triclops::RasterCache.instance.iiif_cache_directory_for_identifier(self.identifier),
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
    # Imogen.with_image(full_base_path, { revalidate: true }) do |image|
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
  # rubocop:enable Metrics/AbcSize

  # Returns an array of scale factors (e.g. [1, 2, 4, 8, 16]), based on the image dimensions
  # and the given tile_size.
  def scale_factors_for_tile_size(tile_size)
    Imogen::Iiif::Tiles.scale_factors_for(self.width, self.height, tile_size)
  end

  def extract_width_and_height_if_missing_or_source_changed!
    # If no source_uri, then there's nothing to extract.
    return if self.source_uri.blank?

    # If width and height are already known, and the source_uri hasn't changed, no need to extract.
    return if self.width.present? && self.height.present? && !source_uri_changed?

    begin
      self.with_source_image_file do |source_image_file|
        # NOTE: Must use `nocache: true` option below so that new width and height
        # are always re-checked for recently rotated images.
        Imogen.with_image(source_image_file.path, { revalidate: true }) do |img|
          self.width = img.width
          self.height = img.height
        end
      end
    rescue Errno::ENOENT => e
      self.errors.add(:source_uri, e.message)
    end
  end

  # Yields a block with a File reference to the source image file for this Resource.
  #
  # @api private
  # @yield source_image_file [File] A file holding the source image content.
  def with_source_image_file
    raise Errno::ENOENT, 'Missing source_uri' if self.source_uri.blank?
    protocol, path = self.source_uri.split('://')

    case protocol
    when 'railsroot'
      yield File.new(Rails.root.join(path).to_s)
      return
    when 'placeholder'
      yield File.new(File.join(PLACEHOLDER_ROOT, path + '.png').to_s)
      return
    when 'file'
      if File.exist?(path)
        yield File.new(path)
        return
      end
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
  #     yield_cached_raster(raster_opts) { |raster_file| yield raster_file }
  #   else
  #     yield_uncached_raster(raster_opts) { |raster_file| yield raster_file }
  #   end
  # end

  def raster_exists?(raster_opts)
    File.exist?(iiif_cache_path(raster_opts))
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
  def iiif_cache_path(raster_opts)
    Triclops::RasterCache.instance.iiif_cache_path(
      source_uri_is_placeholder? ? self.source_uri : self.identifier,
      raster_opts
    )
  end

  # @api private
  def yield_cached_raster(raster_opts)
    # Get cache path
    raster_file_path = iiif_cache_path(raster_opts)

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
  # @return [Boolean] true if source_uri starts with 'placeholder://'
  def source_uri_is_placeholder?
    return false if self.source_uri.nil?
    self.source_uri.start_with?('placeholder://')
  end

  def self.generate_raster_tempfile_path(extension = '.blob')
    loop do
      # Generate unique temp raster in temp location
      raster_tempfile_path = File.join(TRICLOPS[:tmp_directory], "#{Rails.application.class.module_parent_name.underscore}-tmp-#{SecureRandom.uuid}.#{extension}")
      return raster_tempfile_path unless File.exist?(raster_tempfile_path)
    end
  end
end
