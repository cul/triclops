require 'rails_helper'

RSpec.describe Triclops::Iiif::ImagesController::Schemas do
  let(:instance) do
    outer_context = self
    Class.new do
      include outer_context.described_class
    end.new
  end

  context '#raster_params_schema' do
    let(:raster_params) do
      {
        identifier: 'fantastic',
        region: 'full',
        size: 'full',
        rotation: '0',
        quality: 'color',
        format: 'png',
        version: '2',
        download: 'true'
      }
    end

    let(:bad_raster_params) do
      raster_params.merge(quality: 'bad')
    end

    let(:schema) {
      instance.raster_params_schema(
        Triclops::Iiif::Constants::ALLOWED_REGIONS_REGEX,
        Triclops::Iiif::Constants::ALLOWED_SIZES_REGEX,
        Triclops::Iiif::Constants::ALLOWED_ROTATIONS,
        Triclops::Iiif::Constants::ALLOWED_QUALITIES
      )
    }

    it "creates a callable schema that when called, is error free for good params" do
      expect(schema).to be_a(Dry::Schema::Params)
      schema_call_result = schema.call(raster_params.to_h)
      expect(schema_call_result).to be_a(Dry::Schema::Result)
      expect(schema_call_result.errors).to be_blank
    end

    it "creates a schema that when called, produces a call result that automatically casts string values to appropriate types" do
      schema_call_result = schema.call(raster_params)
      expect(schema_call_result[:region]).to be_a(String)
      expect(schema_call_result[:version]).to be_a(Integer)
      expect(schema_call_result[:rotation]).to be_a(Integer)
      expect(schema_call_result[:download]).to be_a(TrueClass)
    end

    it "creates a schema that when called, returns errors for bad values" do
      schema_call_result = schema.call(bad_raster_params)
      expect(schema_call_result.errors).to be_present
    end
  end
end
