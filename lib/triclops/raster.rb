module Triclops
  module Raster
    # Generates a raster file at the given raster_file_path using the given raster_opts.
    # @param source_image_file_path [String]
    #   A file to use as the source for this generated raster.
    # @param raster_file_path [String]
    #   A file path
    # @param raster_opts [Hash]
    #   A hash of IIIF options (e.g. {identifer: '...', region: '...', size: '...', etc. })
    # @return [void]
    def self.generate(source_image_file_path, raster_file_path, raster_opts)
      if File.exist?(raster_file_path)
        raise Triclops::Exceptions::RasterExists, "Raster file already exists at: #{raster_file_path}"
      end
      Imogen.with_image(source_image_file_path) do |img|
        Imogen::Iiif.convert(
          img, raster_file_path, nil, raster_opts
        )
      end
    end
  end
end
