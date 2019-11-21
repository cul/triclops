module Triclops
  module Resource
    module Validations
      extend ActiveSupport::Concern

      included do
        validates :identifier, :location_uri, :width, :height, presence: true
        validates :featured_region, format: { with: /\d+,\d+,\d+,\d+/ }, allow_blank: true
        validates :width, :height, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
      end
    end
  end
end
