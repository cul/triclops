require 'rails_helper'

RSpec.describe Triclops::Raster do
  let(:source_image_file_path) { file_fixture('sample.jpg').to_s }
  let(:raster_opts) do
    {
      identifier: 'sample-identifier',
      region: 'full',
      size: 'full',
      rotation: 0,
      quality: 'color',
      format: 'png'
    }
  end

  context ".generate" do
    context "when file already exists" do
      it "raises an exception if a file already exists at the given raster_path" do
        target_file = Tempfile.new('triclops-test-generate', Dir.tmpdir)
        expect {
          described_class.generate(source_image_file_path, target_file.path, raster_opts)
        }.to raise_error(Triclops::Exceptions::RasterExists)
      ensure
        target_file.unlink
      end
    end

    context "successfully creates a new file with a non-zero size" do
      let(:target_file_path) { Dir::Tmpname.create(['image-', '.png']) {} }
      it do
        expect(File.exist?(target_file_path)).to be(false)
        described_class.generate(source_image_file_path, target_file_path, raster_opts)
        expect(File.exist?(target_file_path)).to be(true)
        expect(File.size(target_file_path)).to be > 0
      ensure
        File.delete(target_file_path)
      end
    end
  end
end
