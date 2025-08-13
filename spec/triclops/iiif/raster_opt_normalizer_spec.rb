require 'rails_helper'

RSpec.describe Triclops::Iiif::RasterOptNormalizer do
  let(:resource) { FactoryBot.create(:resource) }
  let(:region) { 'full' }
  let(:size) { 'full' }
  let(:rotation) { 0 }
  let(:quality) { 'color' }
  let(:raster_opts) do
    {
      region: region,
      size: size,
      rotation: rotation,
      quality: quality
    }
  end

  describe '.normalize_raster_opts' do
    it 'returns the same opts for opts that do not need conversion' do
      expect(described_class.normalize_raster_opts(resource, raster_opts)).to eq(raster_opts)
    end

    context 'when region is "square"' do
      let(:region) { 'square' }
      let(:expected_output) { raster_opts.merge({ region: '320,616,1280,1280' }) }

      it 'converts the region to the x,y,w,h version of the region' do
        expect(described_class.normalize_raster_opts(resource, raster_opts)).to eq(expected_output)
      end
    end

    context 'when quality is "default"' do
      let(:quality) { 'default' }
      let(:expected_output) { raster_opts.merge({ quality: 'color' }) }

      it 'converts the quality to "color"' do
        expect(described_class.normalize_raster_opts(resource, raster_opts)).to eq(expected_output)
      end
    end
  end
end
