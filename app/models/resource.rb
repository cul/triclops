class Resource < ApplicationRecord
  include Triclops::Resource::IiifInfo
  include Triclops::Resource::AsJson
  include Triclops::Resource::Validations
  include Triclops::Resource::DerivativeGeneration

  PCDM_TEXT_TYPES = [
    BestType::PcdmTypeLookup::EMAIL, BestType::PcdmTypeLookup::PAGE_DESCRIPTION, BestType::PcdmTypeLookup::STRUCTURED_TEXT,
    BestType::PcdmTypeLookup::TEXT, BestType::PcdmTypeLookup::UNSTRUCTURED_TEXT
  ].freeze

  LOCAL_FILE_URI_SCHEMES = ['file', 'railsroot', 'placeholder'].freeze

  attr_accessor :create_base_derivatives_now

  enum status: { pending: 0, processing: 1, failure: 2, ready: 3 }

  before_validation :wait_for_source_uri_if_local_disk_file
  before_save :switch_to_pending_state_if_core_properties_changed!
  after_save :queue_base_derivative_generation_if_pending
  after_destroy :delete_file_cache!

  def placeholder?
    self.identifier.start_with?('placeholder:')
  end

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

  # Clear ALL cached image files for this resource.
  def delete_file_cache!
    Triclops::RasterCache.instance_for_writing.delete_cache_for_identifier(self.identifier)
  end

  def queue_base_derivative_generation_if_pending
    return if self.source_uri.nil?
    return unless self.pending?
    if self.create_base_derivatives_now
      Rails.logger.unknown("Creating base derivatives now for #{self.identifier} because create_base_derivatives_now flag was set.")
      CreateBaseDerivativesJob.perform_now(self.identifier)
    else
      CreateBaseDerivativesJob.perform_later(self.identifier)
    end
  end

  # Certain property changes should will trigger a switch to the pending state (which will trigger base
  # derivative regeneration).
  def switch_to_pending_state_if_core_properties_changed!
    return if new_record?

    # TODO: Decide if we also want to include `self.source_uri_changed? ||` in the line below.
    # This would mean that whenever a Resource is saved, we would check if the source uri has changed and
    # regenerate derivatives if it has. The downside is that if an access copy in Hyacinth is relocated and
    # has a different path (but has otheriwse unchanged file content), that will trigger regeneration
    # of Triclops derivatives (which could be wasteful, especially if the source uri is in S3,
    # because we'd need to re-download the file from S3). Would there even be any upsides?
    return unless self.featured_region_changed? || self.pcdm_type_changed?

    self.status = :pending
  end

  def raster_exists?(base_type, raster_opts)
    Triclops::RasterCache.instance_for_reading.storage_object_for_raster(
      base_type,
      self.identifier,
      raster_opts
    ).exist?
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
  def yield_cached_raster(base_type, raster_opts)
    storage_object_for_reading = Triclops::RasterCache.instance_for_reading.storage_object_for_raster(
      base_type,
      self.identifier,
      raster_opts
    )

    unless storage_object_for_reading.exist?
      storage_object_for_writing = Triclops::RasterCache.instance_for_writing.storage_object_for_raster(
        base_type,
        self.identifier,
        raster_opts
      )

      # We use a blocking lock so that two processes don't try to to run the
      # same file creation operation at the same time.
      Triclops::Lock.instance.with_blocking_lock(storage_object_for_writing.location_uri) do
        # We do a second File.exists? check inside of the lock to ensure
        # that file generation does not occur if the file was created
        # while waiting to establish this lock.
        unless storage_object_for_reading.exist?
          storage_object_for_reading.with_file do |source_image_file|
            storage_object_for_writing.write do |dest_file|
              Triclops::Raster.generate(source_image_file.path, dest_file.path, raster_opts)
            end
          end
        end
      end
    end

    storage_object_for_reading.with_file do |file|
      yield File.new(file.path)
    end
  end

  # @api private
  def yield_uncached_raster(base_type, raster_opts)
    storage_object_for_reading = case base_type
                                 when Triclops::Iiif::Constants::BASE_TYPE_STANDARD
                                   # We use the source_uri because we're not currently generating an additional standard base
                                   Triclops::Storage.storage_object_for(self.source_uri)
                                 else
                                   Triclops::RasterCache.instance_for_reading.storage_object_for_base(base_type, self.identifier)
                                 end

    # Newest implementation (TODO: Delete old implementation after verifying that new implementation works as expected)
    Triclops::FileHelper.working_directory_temp_file('tmp-uncached-raster', ".#{raster_opts[:format]}") do |tempfile|
      storage_object_for_reading.with_file do |source_image_file|
        Triclops::Raster.generate(source_image_file.path, tempfile.path, raster_opts)
      end

      yield tempfile
    end
  end
end
