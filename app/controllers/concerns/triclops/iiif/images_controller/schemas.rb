module Triclops
  module Iiif
    module ImagesController
      module Schemas
        extend ActiveSupport::Concern

        def raster_params_schema(region_format_regex, size_format_regex, allowed_rotation_values, allowed_quality_values)
          Dry::Schema.Params do
            required(:version).filled(:integer, eql?: 2) # only supporting version 2 for now
            required(:identifier).filled(:string)
            required(:region).filled(:string, format?: region_format_regex)
            required(:size).filled(:string, format?: size_format_regex)
            required(:rotation).filled(:integer, included_in?: allowed_rotation_values)
            required(:quality).filled(:string, included_in?: allowed_quality_values)
            required(:format).filled(:string)
            optional(:download).filled(:bool)
          end
        end
      end
    end
  end
end
