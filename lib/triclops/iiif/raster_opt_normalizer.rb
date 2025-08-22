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

    # There are multiple variations on the size parameter that could actualy resolve to the same cached image.
    # For example, for a 6485x8690 (w x h) original image, the following three sizes are effectively the same:
    # - 573,768
    # - 573,
    # - ,768
    # - !768,768
    # We don't need to cache all of these variations, so we will instead convert requests for any of them into
    # a request for one of them at a single cached location.
    normalized_opts[:size] = self.normalize_raster_size(resource, raster_opts[:size])

    normalized_opts
  end

  def self.normalize_raster_size(resource, size_raster_opt) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    case size_raster_opt
    when /^\d+,\d+$/
      # Example: "573,768"
      size_raster_opt # Return unmodified original
    when /^\d+,$/
      # Example: "573,"
      width = size_raster_opt[0...-1].to_i
      # Calculate missing height value
      height = (resource.standard_height.to_f / resource.standard_width) * width
      "#{width.round},#{height.round}"
    when /^,\d+$/
      # Example: ",768"
      height = size_raster_opt[1..].to_i
      # Calculate missing width value
      width = (resource.standard_width.to_f / resource.standard_height) * height
      "#{width.round},#{height.round}"
    when /^!\d+,\d+$/
      # Example: "!768,768" or "!100,200" or "!800,600"
      match_data = size_raster_opt.match(/!(\d+),(\d+)/)
      max_width = match_data[1].to_i
      max_height = match_data[2].to_i

      requested_dimensions_aspect_ratio = max_width.to_f / max_height
      original_aspect_ratio = resource.standard_width.to_f / resource.standard_height # 1.5 for wide, 0.75 for tall

      # If the original aspect ratio is larger than the specified region aspect ratio, then we're width-limited and
      # need to scale based on width as the long side. Otherwise we're height limited and need to scale based on height.
      scale_based_on_width = original_aspect_ratio > requested_dimensions_aspect_ratio

      if scale_based_on_width
        width = max_width
        height = (resource.standard_height.to_f / resource.standard_width) * width
      else
        # We'll scale based on height
        height = max_height
        width = (resource.standard_width.to_f / resource.standard_height) * height
      end
      "#{width.round},#{height.round}"
    else
      # Return original value, since it's not a type that we would want to convert.
      size_raster_opt
    end
  end
end
