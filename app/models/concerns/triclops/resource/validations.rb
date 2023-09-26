module Triclops
  module Resource
    module Validations
      extend ActiveSupport::Concern

      included do
        validates :identifier, :location_uri, presence: true
        validates :identifier, length: { minimum: 1, maximum: 255 }
        validates :featured_region, format: { with: /\d+,\d+,\d+,\d+/ }, allow_nil: true
        # We need to allow nil for width and height because they'll be extracted automatically after validation
        validates :width, :height, numericality: { only_integer: true, greater_than_or_equal_to: 1 }, allow_nil: true
        validate :validate_readable_location_uri
      end

      def validate_readable_location_uri
        return if self.location_uri_is_readable?

        errors.add(:location_uri, "is not readable (location_uri: #{location_uri})")
      end
    end
  end
end
