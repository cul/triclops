module Triclops
  module Resource
    module Validations
      extend ActiveSupport::Concern

      included do
        validates :identifier, :location_uri, presence: true
        validates :featured_region, format: { with: /\d+,\d+,\d+,\d+/ }, allow_nil: true
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
