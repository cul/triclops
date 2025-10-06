require 'rails_helper'

RSpec.describe Triclops::Iiif::ImagesController::RasterOptFallbackLogic do
  let(:instance) do
    outer_context = self
    Class.new do
      include outer_context.described_class
    end.new
  end

  let(:identifier) { 'example-identifier' }
  let(:resource) { instance_double(Resource) }
  let(:base_type) { Triclops::Iiif::Constants::BASE_TYPE_STANDARD }
  let(:width) { 256 }
  let(:height) { 190 }
  let(:long_side_length) { width }
  let(:original_raster_opts) do
    {
      region: 'full',
      size: "#{width},",
      rotation: '0',
      quality: 'default',
      format: 'jpg'
    }
  end
  let(:normalized_raster_opts) do
    {
      region: 'full',
      size: "#{width},#{height}",
      rotation: '0',
      quality: 'color',
      format: 'jpg'
    }
  end
  let(:normalized_raster_opts_with_original_size_opt) do
    normalized_raster_opts.merge({ size: original_raster_opts[:size] })
  end
  let(:normalized_raster_opts_with_exclamation_point_long_side_size_notation) do
    normalized_raster_opts.merge({ size: "!#{long_side_length},#{long_side_length}" })
  end

  before do
    allow(resource).to receive(:identifier).and_return(identifier)
  end

  describe '#raster_opts_for_ready_resource_with_fallback' do
    context 'when an associated file exists at the normalized_raster_opts path' do
      before do
        allow(resource).to receive(:raster_exists?).with(base_type, normalized_raster_opts).and_return(true)
      end

      it 'returns the expected opts, and a cache hit of true' do
        expect(instance.raster_opts_for_ready_resource_with_fallback(
                 resource, base_type, original_raster_opts, normalized_raster_opts
               )).to eq([normalized_raster_opts, true])
      end
    end

    context 'when an associated file does not exist at the normalized_raster_opts path, '\
            'but an associated file does exist at the normalized_raster_opts path with the size'\
            'opt replaced with the original_raster_opts size opt' do
      before do
        allow(resource).to receive(:raster_exists?).with(base_type, normalized_raster_opts).and_return(false)
        allow(resource).to receive(:raster_exists?).with(
          base_type, normalized_raster_opts_with_original_size_opt
        ).and_return(true)
      end

      it 'returns the expected opts, and a cache hit of true' do
        expect(instance.raster_opts_for_ready_resource_with_fallback(
                 resource, base_type, original_raster_opts, normalized_raster_opts
               )).to eq([normalized_raster_opts_with_original_size_opt, true])
      end
    end

    context 'when an associated file does not exist at the normalized_raster_opts path, '\
            'and it does not exist at the normalized_raster_opts path with the size'\
            'opt replaced with the original_raster_opts size opt, but it does exist at'\
            'the normalized_raster_opts path with the size replaced with "!long_side,long_side"' do
      before do
        allow(resource).to receive(:raster_exists?).with(base_type, normalized_raster_opts).and_return(false)
        allow(resource).to receive(:raster_exists?).with(
          base_type, normalized_raster_opts_with_original_size_opt
        ).and_return(false)
        allow(resource).to receive(:raster_exists?).with(
          base_type, normalized_raster_opts_with_exclamation_point_long_side_size_notation
        ).and_return(true)
      end

      it 'returns the expected opts, and a cache hit of true' do
        expect(instance.raster_opts_for_ready_resource_with_fallback(
                 resource, base_type, original_raster_opts, normalized_raster_opts
               )).to eq([normalized_raster_opts_with_exclamation_point_long_side_size_notation, true])
      end
    end
  end

  context 'when an associated file does not exist at the normalized_raster_opts path, '\
            'and it does not exist at any other fallback variants' do
    before do
      allow(resource).to receive(:raster_exists?).with(base_type, normalized_raster_opts).and_return(false)
      allow(resource).to receive(:raster_exists?).with(
        base_type, normalized_raster_opts_with_original_size_opt
      ).and_return(false)
      allow(resource).to receive(:raster_exists?).with(
        base_type, normalized_raster_opts_with_exclamation_point_long_side_size_notation
      ).and_return(false)
    end

    it 'returns the expected opts, and a cache hit of false' do
      expect(instance.raster_opts_for_ready_resource_with_fallback(
               resource, base_type, original_raster_opts, normalized_raster_opts
             )).to eq([normalized_raster_opts_with_exclamation_point_long_side_size_notation, false])
    end
  end
end
