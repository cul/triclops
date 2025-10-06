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

    it 'processes the size parameter with an underlying call to normalize_raster_size' do
      expect(described_class).to receive(:normalize_raster_size).with(resource, raster_opts[:size])
      described_class.normalize_raster_opts(resource, raster_opts)
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

    context 'when the resource has a nil standard_width value' do
      before do
        resource.standard_width = nil
      end

      it 'raises an exception' do
        expect {
          described_class.normalize_raster_opts(resource, raster_opts)
        }.to raise_error(Triclops::Exceptions::MissingWidthOrHeightInformation)
      end
    end

    context 'when the resource has a nil standard_height value' do
      before do
        resource.standard_height = nil
      end

      it 'raises an exception' do
        expect {
          described_class.normalize_raster_opts(resource, raster_opts)
        }.to raise_error(Triclops::Exceptions::MissingWidthOrHeightInformation)
      end
    end
  end

  describe '.normalize_raster_size' do
    it 'does not modify an input size of "full"' do
      expect(described_class.normalize_raster_size(resource, 'full')).to eq('full')
    end

    it 'does not modify an input size of "max"' do
      expect(described_class.normalize_raster_size(resource, 'max')).to eq('max')
    end

    it 'does not modify an input size with the format "123,456"' do
      expect(described_class.normalize_raster_size(resource, '123,456')).to eq('123,456')
    end

    context 'when various convertable size values are provided' do
      let(:resource) { FactoryBot.create(:resource, standard_width: 6485, standard_height: 8690) }

      {
        '573,768' => '573,768',
        '573,' => '573,768',
        ',768' => '573,768',
        '!768,768' => '573,768',
        '!100,1234' => '100,134',
        '!1234,100' => '75,100'
      }.each do |input_value, output_value|
        it "converts an input value of #{input_value} to #{output_value}" do
          expect(described_class.normalize_raster_size(resource, input_value)).to eq(output_value)
        end
      end
    end
  end
end
