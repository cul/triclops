module Triclops
  module Resource
    module IiifInfo
      extend ActiveSupport::Concern

      # Returns a IIIF 2.1 info hash about this image resource.
      # @param id_url [String] Identifying URL for this resource.
      # @return [Hash] IIIF 2.1 structured info response.
      def iiif_info(id_url, width, height, sizes, formats, qualities, tile_size)
        {
          '@context': 'http://iiif.io/api/image/2/context.json',
          '@id': id_url,
          'protocol': 'http://iiif.io/api/image',
          'width': width,
          'height': height,
          'sizes': sizes.map { |size| { 'width': size[0], 'height': size[1] } },
          'tiles': [{ 'width': tile_size, 'scaleFactors': [1] }],
          'profile': ['http://iiif.io/api/image/2/level2.json', { 'formats': formats, 'qualities': qualities }]
        }
      end
    end
  end
end
