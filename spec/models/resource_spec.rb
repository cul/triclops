require 'rails_helper'

RSpec.describe Resource, type: :model do
  let(:identifier) { 'test' }
  let(:rails_root_relative_path) { File.join('spec', 'fixtures', 'files', 'sample.jpg') }
  let(:source_file_path) { Rails.root.join(rails_root_relative_path).to_s }
  let(:location_uri) { 'railsroot://' + rails_root_relative_path }
  let(:width) { 1920 }
  let(:height) { 3125 }
  let(:featured_region) { '320,616,1280,1280' }
  let(:instance) do
    described_class.new({
      identifier: identifier,
      location_uri: location_uri,
      width: width,
      height: height,
      featured_region: featured_region
    })
  end
  let(:raster_opts) do
    {
      region: 'full',
      size: 'full',
      rotation: 0,
      quality: 'color',
      format: 'png'
    }
  end

  context '#initialize' do
    it 'successfully creates a new instance and sets up appropriate fields' do
      expect(instance).to be_a(described_class)
      expect(instance.identifier).to eq(identifier)
      expect(instance.width).to eq(width)
      expect(instance.height).to eq(height)
      expect(instance.featured_region).to eq(featured_region)
    end
  end

  context '#raster' do
    let(:featured_raster_opts) { raster_opts.merge(region: 'featured') }
    it 'internally runs preprocessing operations on the raster_opts, converting "featured" region to specific crop region' do
      expect(instance).to receive(:yield_cached_raster).with(hash_including(region: /\d+,\d+,\d+,\d+/)).and_call_original
      instance.raster(featured_raster_opts, true) { |_raster_file| }
    end

    it 'runs yield_cached_raster when cache_enabled arg is true' do
      expect(instance).to receive(:yield_cached_raster).with(raster_opts)
      instance.raster(raster_opts, true) { |_raster_file| }
    end

    it 'runs yield_uncached_raster when cache_enabled arg is false' do
      expect(instance).to receive(:yield_uncached_raster).with(raster_opts)
      instance.raster(raster_opts, false) { |_raster_file| }
    end
  end

  context '#extract_featured_region!' do
    before do
      allow(Imogen::Iiif::Region::Featured).to receive(:get).and_return([10, 20, 30, 40])
    end
    it "extracts the expected region" do
      expect(instance).to receive(:update).with({ featured_region: "10,20,20,20" })
      instance.extract_featured_region!
    end
  end

  context '#yield_uncached_raster' do
    let(:tmp_file_path) { Rails.root.join('tmp', 'test-tmp-file.png').to_s }
    before do
      # For these tests, we always want to receive the same tmp_file_path
      allow(Resource).to receive(:generate_raster_tempfile_path).and_return(tmp_file_path)
    end

    it 'generates a raster file and automatically deletes that raster file after yielding' do
      expect(Triclops::Raster).to receive(:generate).with(source_file_path, tmp_file_path, raster_opts).and_call_original

      instance.yield_uncached_raster(raster_opts) do |raster_file|
        expect(tmp_file_path).to eq(raster_file.path)
        expect(File.exist?(tmp_file_path)).to eq(true)
      end

      expect(File.exist?(tmp_file_path)).to eq(false)
    end
  end

  context '#yield_cached_raster' do
    let(:cache_path) { Rails.root.join('tmp', 'test-file.png').to_s }

    before do
      # We don't need a real lock for this test, so mocking the with_blocking_lock
      # method removes any Redis dependency for this test.
      allow(Triclops::Lock.instance).to receive(:with_blocking_lock).and_yield
      # For these tests, we always want to receive the same cache_path
      allow(Triclops::RasterCache.instance).to receive(:cache_path).and_return(cache_path)
    end

    after do
      # Clean up file created by test
      File.delete(cache_path) if File.exist?(cache_path)
    end

    it 'when an existing raster file does not exist, generates and caches a new raster file and yields that new raster file' do
      expect(Triclops::Raster).to receive(:generate).with(source_file_path, cache_path, raster_opts).and_call_original

      instance.yield_cached_raster(raster_opts) do |raster_file|
        expect(cache_path).to eq(raster_file.path)
      end
    end

    it 'when an existing raster file exists, yields that existing raster file and does not call the generate method internally' do
      # Generate the raster
      instance.yield_cached_raster(raster_opts) do |raster_file|
      end

      # Then call yield_cached_raster again to return the already-generated raster
      expect(Triclops::Raster).not_to receive(:generate)
      instance.yield_cached_raster(raster_opts) do |raster_file|
        expect(cache_path).to eq(raster_file.path)
      end
    end
  end

  context '#with_source_image_file' do
    context "with a railsroot:// path" do
      it "returns the path to an existing file" do
        allow(instance).to receive(:location_uri).and_return('railsroot://spec/fixtures/files/sample-with-transparency.png')

        instance.with_source_image_file do |file|
          expect(Rails.root.join('spec', 'fixtures', 'files', 'sample-with-transparency.png').to_s).to eq(file.path)
        end
      end

      it "raises an error for a file that doesn't exist" do
        allow(instance).to receive(:location_uri).and_return('railsroot://nofile.png')
        expect { instance.with_source_image_file { |_file| } }.to raise_error(Errno::ENOENT)
      end
    end

    context "with a placeholder:// path" do
      it "returns the path to an existing file" do
        allow(instance).to receive(:location_uri).and_return('placeholder://sound')

        instance.with_source_image_file do |file|
          expect(Rails.root.join('app', 'assets', 'images', 'placeholders', 'sound.png').to_s).to eq(file.path)
        end
      end

      it "raises an error for a file that doesn't exist" do
        allow(instance).to receive(:location_uri).and_return('placeholder://nofile')
        expect { instance.with_source_image_file { |_file| } }.to raise_error(Errno::ENOENT)
      end
    end

    context 'with an absolute file:// path' do
      it "returns the path to an existing file" do
        temp_file_path = Dir.tmpdir + '/triclops-test-file.png'
        FileUtils.touch(temp_file_path)
        allow(instance).to receive(:location_uri).and_return('file://' + temp_file_path)

        instance.with_source_image_file do |file|
          expect(temp_file_path).to eq(file.path)
        end
      ensure
        File.unlink(temp_file_path)
      end

      it "raises an error for a file that doesn't exist" do
        allow(instance).to receive(:location_uri).and_return('file:///no/file/here.png')
        expect { instance.with_source_image_file { |_file| } }.to raise_error(Errno::ENOENT)
      end
    end

    it "raises an error for an unsupported protocol" do
      allow(instance).to receive(:location_uri).and_return('abc://what/does/this/protocol/even/mean.png')
      expect { instance.with_source_image_file { |_file| } }.to raise_error(Errno::ENOENT)
    end
  end

  context '.generate_raster_tempfile_path' do
    let(:triclops_tmp_directory) { Dir.tmpdir }
    let(:extension) { 'png' }
    before do
      stub_const("TRICLOPS", TRICLOPS.dup.merge(tmp_directory: triclops_tmp_directory))
    end

    it "generates a file path the Triclops tmp directory with the specified extension, and the file does not exist" do
      tempfile_path = described_class.generate_raster_tempfile_path(extension)
      expect(tempfile_path).to start_with(triclops_tmp_directory)
      expect(tempfile_path).to end_with(extension)
      expect(File.exist?(tempfile_path)).to be(false)
    end

    it "multiple calls return different values" do
      expect(
        described_class.generate_raster_tempfile_path(extension)
      ).not_to eq(
        described_class.generate_raster_tempfile_path(extension)
      )
    end
  end

  context '#cache_path' do
    it 'works as expected for a non-placeholder location_uri' do
      expect(instance.cache_path(raster_opts)).to eq(
        "#{TRICLOPS[:raster_cache][:directory]}/9f/86/d0/81/"\
        '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08/full/full/0/color.png'
      )
    end

    it 'works as expected for a placeholder location_uri' do
      instance.location_uri = 'placeholder://cool'
      expect(instance.cache_path(raster_opts)).to eq(
        "#{TRICLOPS[:raster_cache][:directory]}/63/0f/dc/84/"\
        '630fdc84e37d2c114ca6afdccb24fdc534bdd5f363745fe26833607fb067a080/full/full/0/color.png'
      )
    end
  end

  context '#location_uri_is_placeholder?' do
    it 'returns false when location uri does not start with placeholder://' do
      expect(instance.location_uri_is_placeholder?).to eq(false)
    end

    it 'returns true when location uri starts with placeholder://' do
      instance.location_uri = 'placeholder://cool'
      expect(instance.location_uri_is_placeholder?).to eq(true)
    end
  end

  context 'validation' do
    it 'does not allow empty values for certain fields' do
      instance.identifier = nil
      instance.width = nil
      instance.height = nil
      instance.location_uri = nil
      expect(instance.valid?).to be false
      expect(instance.errors.keys).to include(:identifier, :width, :height, :location_uri)
    end

    it 'validates featured_region format, but also allows a nil value' do
      expect(instance.valid?).to be true
      instance.featured_region = nil
      expect(instance.valid?).to be true
      instance.featured_region = 'not valid!'
      expect(instance.valid?).to be false
      expect(instance.errors.keys).to include(:featured_region)
    end
  end

  context 'two resources with the same location_uri value' do
    let(:resource1) do
      Resource.new({
        identifier: 'id1',
        location_uri: location_uri,
        width: width,
        height: height,
        featured_region: featured_region
      })
    end
    let(:resource2) do
      Resource.new({
        identifier: 'id2',
        location_uri: location_uri,
        width: width,
        height: height,
        featured_region: featured_region
      })
    end
    let(:raster_opts_base) do
      {
        region: 'full',
        size: 'full',
        rotation: 0,
        quality: 'color',
        format: 'png'
      }
    end
    context 'should use different cache paths when both resources have the same NON-"placeholder://"-prefixed location_uri value' do
      it do
        resource1_raster_path = nil
        resource2_raster_path = nil
        resource1.raster(raster_opts, true) { |raster_file| resource1_raster_path = raster_file.path }
        resource2.raster(raster_opts, true) { |raster_file| resource2_raster_path = raster_file.path }
        expect(resource1_raster_path).not_to eq(resource2_raster_path)
      end
    end

    context 'should use the same cache path when both resources have the same "placeholder://"-prefixed location_uri value' do
      let(:location_uri) { 'placeholder://sound' }
      it do
        resource1_raster_path = nil
        resource2_raster_path = nil
        resource1.raster(raster_opts, true) { |raster_file| resource1_raster_path = raster_file.path }
        resource2.raster(raster_opts, true) { |raster_file| resource2_raster_path = raster_file.path }
        expect(resource1_raster_path).to eq(resource2_raster_path)
      end
    end
  end
end
