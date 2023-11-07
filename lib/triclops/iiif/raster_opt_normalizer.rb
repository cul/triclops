module Triclops::Iiif::RasterOptNormalizer
  # Pre-processes raster opts before they're used later in the conversion chain.
  # Performs operations like converting a 'square' region into a numeric crop
  # region and aliasing 'color' quality as 'default' quality.
  #
  # @api private
  # @param raster_opts [Hash]
  #   A hash of IIIF options (e.g. {identifier: '...', region: '...', size: '...', etc. }).
  # @return [Hash] the processed version of raster_opts
  def self.normalize_raster_opts(resource, raster_opts)
    # duplicate raster_opts so we don't modify the incoming argument
    normalized_opts = raster_opts.dup

    # {region: 'square'} should be converted into {region: 'x,y,w,h'}
    normalized_opts[:region] = resource.featured_region if normalized_opts[:region] == 'square'

    # {quality: 'default'} should be converted into {quality: 'color'} because that is our default
    normalized_opts[:quality] = 'color' if normalized_opts[:quality] == 'default'

    normalized_opts
  end
end
