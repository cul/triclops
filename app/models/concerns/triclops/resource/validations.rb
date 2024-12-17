module Triclops
  module Resource
    module Validations
      extend ActiveSupport::Concern

      included do
        validates :identifier, :pcdm_type, :source_uri, presence: true
        validates :identifier, length: { minimum: 1, maximum: 255 }
        validates :standard_width, :standard_height,
                  :limited_width, :limited_height,
                  :featured_width, :featured_height,
                  numericality: { only_integer: true, greater_than_or_equal_to: 1 }, allow_nil: true
        validates :featured_region, format: { with: /\d+,\d+,\d+,\d+/ }, allow_nil: true
        validate :validate_readable_source_uri_if_present
        validate :validate_featured_region_present_if_source_uri_present
      end

      def validate_readable_source_uri_if_present
        return if source_uri.blank? || self.source_uri_is_readable?

        errors.add(:source_uri, "is not readable (source_uri: #{source_uri})")
      end

      def validate_featured_region_present_if_source_uri_present
        return if self.source_uri.blank? || self.featured_region.present?

        errors.add(:featured_region, 'is required for the given source_uri image')
      end
    end
  end
end
