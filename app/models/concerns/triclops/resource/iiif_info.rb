module Triclops
  module Resource
    module IiifInfo
      extend ActiveSupport::Concern

      # Returns a IIIF 2.1 info hash about this image resource.
      # @param id_url [String] Identifying URL for this resource.
      # @return [Hash] IIIF 2.1 structured info response.
      def iiif_info(id_url, width, height, sizes, formats, qualities, tile_size, scale_factors)
        {
          '@context': 'http://iiif.io/api/image/2/context.json',
          '@id': id_url,
          'protocol': 'http://iiif.io/api/image',
          'width': width,
          'height': height,
          'sizes': sizes.map { |size| { 'width': size[0], 'height': size[1] } },
          'tiles': tile_info(tile_size, scale_factors),
          'profile': ['http://iiif.io/api/image/2/level2.json', { 'formats': formats, 'qualities': qualities }]
        }
      end

      def tile_info(tile_size, scale_factors)
        [{
          'width': tile_size,
          # 'height': tile_size, # when height is omitted, IIIF interprets that as "height is the same as width"
          'scaleFactors': scale_factors
        }]
      end
    end
  end
end
