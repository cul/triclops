module Triclops
  class RasterCache
    # Singleton pattern Triclops::RasterCache instance for this class.
    def self.instance
      @instance ||= new(TRICLOPS[:raster_cache][:directory])
    end

    def initialize(cache_directory)
      @cache_directory = cache_directory
    end

    def full_base_cache_path(identifier, mkdir_p: false)
      File.join(
        base_cache_directory_for_identifier(identifier, mkdir_p: mkdir_p),
        "full.#{Triclops::Iiif::Constants::BASE_IMAGE_FORMAT}"
      )
    end

    def reduced_base_cache_path(identifier, mkdir_p: false)
      File.join(
        base_cache_directory_for_identifier(identifier, mkdir_p: mkdir_p),
        "reduced.#{Triclops::Iiif::Constants::BASE_IMAGE_FORMAT}"
      )
    end

    def square_base_cache_path(identifier, mkdir_p: false)
      File.join(
        base_cache_directory_for_identifier(identifier, mkdir_p: mkdir_p),
        "square.#{Triclops::Iiif::Constants::BASE_IMAGE_FORMAT}"
      )
    end

    # Returns the full cache path to a raster file.
    # @param raster_opts {Hash} Raster options for the desired raster.
    def iiif_cache_path(identifier, raster_opts, mkdir_p: false)
      dir = File.join(
        iiif_cache_directory_for_identifier(identifier),
        raster_opts[:region],
        raster_opts[:size],
        raster_opts[:rotation].to_s
      )
      FileUtils.mkdir_p(dir) if mkdir_p
      File.join(dir, "#{raster_opts[:quality]}.#{raster_opts[:format]}")
    end

    def base_cache_directory_for_identifier(identifier, mkdir_p: false)
      dir = File.join(
        cache_directory_for_identifier(identifier),
        'base'
      )
      FileUtils.mkdir_p(dir) if mkdir_p
      dir
    end

    def iiif_cache_directory_for_identifier(identifier, mkdir_p: false)
      dir = File.join(
        cache_directory_for_identifier(identifier),
        'iiif'
      )
      FileUtils.mkdir_p(dir) if mkdir_p
      dir
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
