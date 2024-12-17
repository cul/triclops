module Triclops
  class RasterCache
    # Singleton pattern Triclops::RasterCache instance for this class.
    def self.instance
      @instance ||= new(TRICLOPS[:raster_cache][:directory])
    end

    def initialize(cache_directory)
      @cache_directory = cache_directory
    end

    def cache_root_relative_path_for_identifier(identifier)
      digest = Digest::SHA256.hexdigest(identifier)
      File.join(digest[0..1], digest[2..3], digest[4..5], digest[6..7], digest)
    end

    def cache_directory_for_identifier(identifier)
      File.join(
        @cache_directory,
        cache_root_relative_path_for_identifier(identifier)
      )
    end

    def base_type_directory_for_identifier(base_type, identifier)
      unless Triclops::Iiif::Constants::ALLOWED_BASE_TYPES.include?(base_type)
        raise ArgumentError,
              "Unallowed base type #{base_type}.  Must be one of: #{Triclops::Iiif::Constants::ALLOWED_BASE_TYPES.join(', ')}"
      end
      File.join(
        cache_directory_for_identifier(identifier),
        base_type
      )
    end

    def base_cache_path(base_type, identifier, mkdir_p: false)
      base_type_directory = base_type_directory_for_identifier(base_type, identifier)
      FileUtils.mkdir_p(base_type_directory) if mkdir_p
      File.join(
        base_type_directory,
        "base.#{Triclops::Iiif::Constants::BASE_IMAGE_FORMAT}"
      )
    end

    def iiif_cache_directory_for_identifier(base_type, identifier, mkdir_p: false)
      dir = File.join(
        base_type_directory_for_identifier(base_type, identifier),
        'iiif'
      )
      FileUtils.mkdir_p(dir) if mkdir_p
      dir
    end

    # Returns the full cache path to a raster file.
    # @param base_type {String} The base_type (standard, limited, or featured)
    # @param raster_opts {Hash} Raster options for the desired raster.
    def iiif_cache_path_for_raster(base_type, identifier, raster_opts, mkdir_p: false)
      dir = File.join(
        iiif_cache_directory_for_identifier(base_type, identifier),
        raster_opts[:region],
        raster_opts[:size],
        raster_opts[:rotation].to_s
      )
      FileUtils.mkdir_p(dir) if mkdir_p
      File.join(dir, "#{raster_opts[:quality]}.#{raster_opts[:format]}")
    end
  end
end
