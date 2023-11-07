# frozen_string_literal: true

module Triclops
  module Contracts
    class Iiif2ImageParamsContract < ::Dry::Validation::Contract
      params do
        required(:version).value(:integer, eql?: 2)
        required(:identifier).value(:string)
        required(:region).value(:string, format?: Triclops::Iiif::Constants::ALLOWED_REGIONS_REGEX)
        required(:size).value(:string, format?: Triclops::Iiif::Constants::ALLOWED_SIZES_REGEX)
        required(:rotation).value(:integer, included_in?: Triclops::Iiif::Constants::ALLOWED_ROTATIONS)
        required(:quality).value(:string, included_in?: Triclops::Iiif::Constants::ALLOWED_QUALITIES)
        required(:format).value(:string)
        optional(:download).value(:bool)
      end

      # rule(:region) do
      #     key.failure("value '#{value}' is not an known type") unless
      #       Triclops::Iiif::Constants::ALLOWED_REGIONS_REGEX.include?(values[:region])
      # end
    end
  end
end
