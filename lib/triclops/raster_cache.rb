module Triclops
  class RasterCache
    FILE_STORAGE_TYPE = :file
    S3_STORAGE_TYPE = :s3
    SUPPORTED_STORAGE_TYPES = [FILE_STORAGE_TYPE, S3_STORAGE_TYPE].freeze

    # If a batch deletion operation tries to delete more than this many objects,
    # an error will be raised and the deletion will not go through. This is here
    # to prevent dangerous effect if a bug is later introduced into the code.
    BATCH_DELETION_SAFETY_LIMIT = 1000

    REQUIRED_RASTER_OPTS_FOR_PATH_DETERMINATION = [:region, :size, :rotation, :quality, :format].freeze

    def self.instance_for_reading
      @instance_for_reading ||= begin
        cache_root_location = File.join(TRICLOPS[:raster_cache][:read_location_prefix], TRICLOPS[:raster_cache][:path])
        self.new(cache_root_location)
      end
    end

    def self.instance_for_writing
      @instance_for_writing ||= begin
        cache_root_location = File.join(TRICLOPS[:raster_cache][:write_location_prefix], TRICLOPS[:raster_cache][:path])
        self.new(cache_root_location)
      end
    end

    def self.storage_type_for_storage_location(storage_location)
      if storage_location.start_with?('file://')
        return FILE_STORAGE_TYPE
      elsif storage_location.start_with?('s3://')
        return S3_STORAGE_TYPE
      end

      nil
    end

    def initialize(cache_root_location)
      if self.class.storage_type_for_storage_location(cache_root_location).nil?
        raise ArgumentError, "Unsupported cache_root_location protocol (\"#{cache_root_location}\"). Must start with: #{SUPPORTED_STORAGE_TYPES.map { |protocol| "#{protocol}://" }.join(' or ')}"
      end

      @cache_root_location = cache_root_location
    end

    def cache_root_relative_path_for_identifier(identifier)
      digest = Digest::SHA256.hexdigest(identifier)
      File.join(digest[0..1], digest[2..3], digest[4..5], digest[6..7], digest)
    end

    def cache_location_for_identifier_directory(identifier)
      File.join(
        @cache_root_location,
        cache_root_relative_path_for_identifier(identifier)
      )
    end

    def cache_location_for_base_directory(base_type, identifier)
      unless Triclops::Iiif::Constants::ALLOWED_BASE_TYPES.include?(base_type)
        raise ArgumentError,
              "Unallowed base type #{base_type}.  Must be one of: #{Triclops::Iiif::Constants::ALLOWED_BASE_TYPES.join(', ')}"
      end
      File.join(
        self.cache_location_for_identifier_directory(identifier),
        base_type
      )
    end

    def cache_location_for_base_image(base_type, identifier)
      base_type_directory = self.cache_location_for_base_directory(base_type, identifier)
      File.join(
        base_type_directory,
        "base.#{Triclops::Iiif::Constants::BASE_IMAGE_FORMAT}"
      )
    end

    def iiif_cache_location_for_identifier_directory(base_type, identifier)
      File.join(
        self.cache_location_for_base_directory(base_type, identifier),
        'iiif'
      )
    end

    # Returns the full cache location for a raster file.
    # @param base_type {String} The base_type (standard, limited, or featured)
    # @param identifier {String} The identifier for the resource.
    # @param raster_opts {Hash} Raster options for the desired raster.
    def iiif_cache_location_for_raster(base_type, identifier, raster_opts)
      ensure_required_raster_opts!(raster_opts)

      dir = File.join(
        iiif_cache_location_for_identifier_directory(base_type, identifier),
        raster_opts[:region],
        raster_opts[:size],
        raster_opts[:rotation].to_s
      )
      File.join(dir, "#{raster_opts[:quality]}.#{raster_opts[:format]}")
    end

    # Returns a StorageObject for the raster specified by the given params
    def storage_object_for_raster(base_type, identifier, raster_opts)
      cache_location = iiif_cache_location_for_raster(base_type, identifier, raster_opts)
      Triclops::Storage.storage_object_for(cache_location)
    end

    # Returns a StorageObject for the base image specified by the given params
    def storage_object_for_base(base_type, identifier)
      cache_location = cache_location_for_base_image(base_type, identifier)
      Triclops::Storage.storage_object_for(cache_location)
    end

    def delete_cache_for_identifier(identifier)
      cache_directory_location = self.cache_location_for_identifier_directory(identifier)
      case self.class.storage_type_for_storage_location(@cache_root_location)
      when FILE_STORAGE_TYPE
        FileUtils.rm_rf(Triclops::Utils::UriUtils.location_uri_to_file_path(cache_directory_location))
      when S3_STORAGE_TYPE
        storage_object = Triclops::Storage.storage_object_for(cache_directory_location)

        bucket_name = storage_object.s3_object.bucket_name
        prefix = storage_object.s3_object.key
        prefix = "#{prefix}/" unless prefix.end_with?('/')

        s3_resource = Aws::S3::Resource.new(client: S3_CLIENT)
        bucket = s3_resource.bucket(bucket_name)
        objects = bucket.objects(prefix: prefix)

        # As a safety measure, make sure prefix isn't blank
        raise 'Halting deletion process because prefix is blank.' if prefix.blank?

        # As a safety measure, check the number of objects to be deleted
        count = 0
        objects.each { |_obj| count += 1 }
        if count > BATCH_DELETION_SAFETY_LIMIT
          raise "Halting deletion process because over #{BATCH_DELETION_SAFETY_LIMIT} objects were identified for "\
                'deletion. This high number of objects seems like a mistake.'
        end

        Rails.logger.info "Deleting #{count} objects under #{cache_directory_location}"
        bucket.objects(prefix: prefix).batch_delete!
      end
    end

    def ensure_required_raster_opts!(raster_opts)
      missing_required_raster_opts_keys = REQUIRED_RASTER_OPTS_FOR_PATH_DETERMINATION - raster_opts.keys
      return if missing_required_raster_opts_keys.empty?

      raise ArgumentError, "Required raster_opts keys are: #{REQUIRED_RASTER_OPTS_FOR_PATH_DETERMINATION.inspect}. Missing: #{missing_required_raster_opts_keys.inspect}"
    end
  end
end
