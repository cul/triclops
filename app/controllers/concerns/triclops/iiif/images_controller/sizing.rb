module Triclops
  module Iiif
    module ImagesController
      module Sizing
        extend ActiveSupport::Concern

        # Given a width and height, scales the larger of the two values to the
        # given size, and proportionally scales the other value.
        # @param size [Integer] Target size
        # @param width [Integer] A given width
        # @param height [Integer] A given height
        # @return [Array] An array holding scaled values, of the format: [width, height]
        def closest_size(size, width, height)
          raise ArgumentError, 'Invalid size' if size.zero?
          raise ArgumentError, 'Invalid width' if width.zero?
          raise ArgumentError, 'Invalid height' if height.zero?

          if width > height
            scaled_width = size
            scaled_height = (height * (size.to_f / width)).round
          else
            scaled_height = size
            scaled_width = (width * (size.to_f / height)).round
          end
          [scaled_width, scaled_height]
        end
      end
    end
  end
end
