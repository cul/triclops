class Resource < ApplicationRecord
  include Triclops::Resource::IiifInfo
  include Triclops::Resource::AsJson
  include Triclops::Resource::Validations
  include Triclops::Resource::DerivativeGeneration

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
