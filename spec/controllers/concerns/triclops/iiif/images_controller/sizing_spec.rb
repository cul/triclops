require 'rails_helper'

RSpec.describe Triclops::Iiif::ImagesController::Sizing do
  let(:instance) do
    outer_context = self
    Class.new do
      include outer_context.described_class
    end.new
  end

  context '#closest_size' do
    it "converts as expected" do
      expect(instance.closest_size(512, 100, 100)).to eq([512, 512])
      expect(instance.closest_size(512, 200, 100)).to eq([512, 256])
      expect(instance.closest_size(512, 100, 200)).to eq([256, 512])

      expect(instance.closest_size(512, 1000, 1000)).to eq([512, 512])
      expect(instance.closest_size(512, 2000, 1000)).to eq([512, 256])
      expect(instance.closest_size(512, 1000, 2000)).to eq([256, 512])
    end

    it 'raises an exception for invalid values' do
      expect { instance.closest_size(0, 1000, 2000) }.to raise_error(ArgumentError)
      expect { instance.closest_size(512, 0, 1000) }.to raise_error(ArgumentError)
      expect { instance.closest_size(512, 1000, 0) }.to raise_error(ArgumentError)
    end
  end
end
