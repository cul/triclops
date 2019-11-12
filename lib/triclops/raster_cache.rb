module Triclops
  class RasterCache
    # Singleton pattern Triclops::RasterCache instance for this class.
    def self.instance
      @instance ||= new(TRICLOPS[:raster_cache][:directory])
    end

    def initialize(cache_directory)
      @cache_directory = cache_directory
    end

    # Returns the full cache path to a raster file.
    # @param raster_opts {Hash} Raster options for the desired raster.
    def cache_path(identifier, raster_opts)
      File.join(
        cache_directory_for_identifier(identifier),
        raster_opts[:region],
        raster_opts[:size],
        raster_opts[:rotation].to_s,
        "#{raster_opts[:quality]}.#{raster_opts[:format]}"
      )
    end

    def cache_directory_for_identifier(identifier)
      File.join(
        @cache_directory,
        cache_root_relative_path_for_identifier(identifier)
      )
    end

    def cache_root_relative_path_for_identifier(identifier)
      digest = Digest::SHA256.hexdigest(identifier)
      File.join(digest[0..1], digest[2..3], digest[4..5], digest[6..7], digest)
    end
  end
end
