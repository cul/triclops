require 'rails_helper'

RSpec.describe Triclops::RasterCache do
  let(:cache_directory) { TRICLOPS[:raster_cache][:directory] }
  let(:instance) do
    described_class.new(cache_directory)
  end
  let(:identifier) { 'some-identifier' }
  let(:raster_opts) do
    {
      region: 'full',
      size: 'full',
      rotation: 0,
      quality: 'color',
      format: 'png'
    }
  end

  context ".instance" do
    it "creates and returns a singleton of the correct type" do
      expect(described_class.instance).to be_a(described_class)
    end

    it "returns the same object instance when called multiple times" do
      obj1 = described_class.instance
      obj2 = described_class.instance
      expect(obj1).to equal(obj2)
    end
  end

  context '#initialize' do
    it 'successfully creates a new instance and sets up appropriate instance variables' do
      expect(instance).to be_a(described_class)
      expect(instance.instance_variable_get('@cache_directory')).to eq(cache_directory)
    end
  end

  context '#cache_root_relative_path_for_identifier' do
    it 'returns the expected value' do
      expect(instance.cache_root_relative_path_for_identifier(identifier)).to eq('c7/b0/1c/2c/c7b01c2c7f3383eba7c7e993ab921f5a8dc06421f67120d7dfe8735673fc2d32')
    end
  end

  context '#cache_directory_for_identifier' do
    it 'returns the expected value' do
      expect(instance.cache_directory_for_identifier(identifier)).to eq(File.join(cache_directory, 'c7/b0/1c/2c/c7b01c2c7f3383eba7c7e993ab921f5a8dc06421f67120d7dfe8735673fc2d32'))
    end
  end

  context '#iiif_cache_path' do
    it 'returns the expected value' do
      expect(instance.iiif_cache_path(identifier, raster_opts)).to eq(File.join(cache_directory, 'c7/b0/1c/2c/c7b01c2c7f3383eba7c7e993ab921f5a8dc06421f67120d7dfe8735673fc2d32/iiif/full/full/0/color.png'))
    end
  end
end
