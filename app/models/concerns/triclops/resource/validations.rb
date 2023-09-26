module Triclops
  module Resource
    module Validations
      extend ActiveSupport::Concern

      included do
        validates :identifier, :location_uri, presence: true
        validates :identifier, length: { minimum: 1, maximum: 255 }
        validates :secondary_identifier, length: { minimum: 1, maximum: 255 }, allow_nil: true
        validates :featured_region, format: { with: /\d+,\d+,\d+,\d+/ }, allow_nil: true
        # We need to allow nil for width and height because they'll be extracted automatically after validation
        validates :width, :height, numericality: { only_integer: true, greater_than_or_equal_to: 1 }, allow_nil: true
        validate :validate_readable_location_uri
        validate :validate_uniqueness_of_identifiers
      end

      def validate_readable_location_uri
        return if self.location_uri_is_readable?

        errors.add(:location_uri, "is not readable (location_uri: #{location_uri})")
      end

      def validate_uniqueness_of_identifiers
        # We also have unique indexes on the identifier and secondary_identifier DB columns, but
        # these can only catch same-column duplicates. Also, it's nice to catch duplicates as
        # validation errors rather than having to handle db-adapter-specific constraint exceptions.

        if self.identifier == self.secondary_identifier
          errors.add(:identifier, "cannot be the same as #{secondary_identifier}")
        end

        identifier_exists =
          ::Resource.where
                    .not(self.new_record? ? {} : { id: self.id })
                    .and(
                      ::Resource.where(identifier: self.identifier)
                                .or(::Resource.where(secondary_identifier: self.identifier))
                    )
                    .count.positive?

        secondary_identifier_exists =
          ::Resource.where
                    .not(self.new_record? ? {} : { id: self.id })
                    .and(
                      ::Resource.where(identifier: self.secondary_identifier)
                                .or(::Resource.where(secondary_identifier: self.secondary_identifier))
                    )
                    .count.positive?

        if identifier_exists
          errors.add(
            :identifier, 'is already taken by another record with the same identifier or secondary_identifier'
          )
        end

        if secondary_identifier_exists
          errors.add(
            :secondary_identifier, 'is already taken by another record with the same identifier or secondary_identifier'
          )
        end
      end
    end
  end
end
