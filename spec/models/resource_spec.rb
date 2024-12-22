require 'rails_helper'

RSpec.describe Resource, type: :model do
  let(:base_type) { Triclops::Iiif::Constants::BASE_TYPE_STANDARD }
  let(:identifier) { 'test' }
  let(:rails_root_relative_image_path) { File.join('spec', 'fixtures', 'files', 'sample.jpg') }
  let(:source_file_path) { Rails.root.join(rails_root_relative_image_path).to_s }
  let(:source_uri) { 'railsroot://' + rails_root_relative_image_path }
  let(:standard_width) { 1920 }
  let(:standard_height) { 3125 }
  let(:featured_region) { '320,616,1280,1280' }
  let(:instance) do
    described_class.new({
      identifier: identifier,
      source_uri: source_uri,
      standard_width: standard_width,
      standard_height: standard_height,
      featured_region: featured_region,
      pcdm_type: BestType::PcdmTypeLookup::IMAGE
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
      expect(instance.standard_width).to eq(standard_width)
      expect(instance.standard_height).to eq(standard_height)
      expect(instance.featured_region).to eq(featured_region)
    end
  end

  # context '#extract_width_and_height_if_missing_or_source_changed!' do
  #   let(:width) { nil }
  #   let(:height) { nil }
  #   let(:image_double) do
  #     instance_double('image').tap do |dbl|
  #       allow(dbl).to receive(:width).and_return(1920)
  #       allow(dbl).to receive(:height).and_return(3125)
  #     end
  #   end

  #   before do
  #     allow(Imogen).to receive(:with_image).and_yield(image_double)
  #     # Skip base derivative generation for this set of tests
  #     allow(instance).to receive(:queue_base_derivative_generation_if_pending)
  #   end

  #   context "for a new resource instance that has a source_uri, but does not currently store width or height" do
  #     it "extracts the expected width" do
  #       expect(instance).to receive(:width=).with(1920)
  #       instance.extract_width_and_height_if_missing_or_source_changed!
  #     end

  #     it "extracts the expected height" do
  #       expect(instance).to receive(:height=).with(3125)
  #       instance.extract_width_and_height_if_missing_or_source_changed!
  #     end
  #   end

  #   context "when the source_uri HAS NOT changed, and the method is called again" do
  #     before do
  #       # Extract properties and save before upcoming tests run
  #       instance.extract_width_and_height_if_missing_or_source_changed!
  #       instance.save
  #       expect(instance.errors.full_messages).to be_blank
  #     end

  #     it "does not re-extract the width" do
  #       expect(instance).not_to receive(:width=)
  #       instance.extract_width_and_height_if_missing_or_source_changed!
  #     end

  #     it "does not re-extract the height" do
  #       expect(instance).not_to receive(:height=)
  #       instance.extract_width_and_height_if_missing_or_source_changed!
  #     end
  #   end

  #   context "when the source_uri HAS changed, and the method is called again" do
  #     before do
  #       # Extract properties and save before upcoming tests run
  #       instance.extract_width_and_height_if_missing_or_source_changed!
  #       instance.save
  #       # Then change the source uri to nil and save
  #       instance.source_uri = nil
  #       instance.save
  #       # And then reassign the source_uri to the original value
  #       instance.source_uri = source_uri
  #     end

  #     it "does not re-extract the width" do
  #       expect(instance).to receive(:width=)
  #       instance.extract_width_and_height_if_missing_or_source_changed!
  #     end

  #     it "does not re-extract the height" do
  #       expect(instance).to receive(:height=)
  #       instance.extract_width_and_height_if_missing_or_source_changed!
  #     end
  #   end
  # end

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
    before do
      # We don't need a real lock for this test, so mocking the with_blocking_lock
      # method removes any Redis dependency for this test.
      allow(Triclops::Lock.instance).to receive(:with_blocking_lock).and_yield
    end

    after do
      # Clean up files created by the test
      instance.delete_filesystem_cache!
    end

    it 'when an existing raster file does not exist, generates and caches a new raster file and yields that new raster file' do
      expected_cache_path = Triclops::RasterCache.instance.iiif_cache_path_for_raster(base_type, instance.identifier, raster_opts)
      expect(Triclops::Raster).to receive(:generate).with(source_file_path, expected_cache_path, raster_opts).and_call_original

      instance.yield_cached_raster(base_type, raster_opts) do |raster_file|
        expect(raster_file.path).to eq(expected_cache_path)
      end
    end

    it 'yields the same raster file when called multiple times, and does not regenerate the file for the second yield' do
      # Generate the raster
      path_from_first_yield = nil
      instance.yield_cached_raster(base_type, raster_opts) do |raster_file|
        path_from_first_yield = raster_file.path
      end

      # Then call yield_cached_raster again to return the already-generated raster
      expect(Triclops::Raster).not_to receive(:generate)
      instance.yield_cached_raster(base_type, raster_opts) do |raster_file|
        expect(path_from_first_yield).to eq(raster_file.path)
      end
    end

    context 'when two different resources have different identifiers, but the same source_uri value' do
      let(:resource1) do
        FactoryBot.create(:resource, source_uri: source_uri)
      end
      let(:resource2) do
        FactoryBot.create(:resource, source_uri: source_uri)
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

      after do
        # Cleanup after tests
        resource1.delete_filesystem_cache!
        resource2.delete_filesystem_cache!
      end

      context 'when both resources have the same NON-"placeholder://"-prefixed source_uri value' do
        it 'results in two different raster cache paths for each resource' do
          resource1_raster_path = nil
          resource2_raster_path = nil
          resource1.yield_cached_raster(base_type, raster_opts) { |raster_file| resource1_raster_path = raster_file.path }
          resource2.yield_cached_raster(base_type, raster_opts) { |raster_file| resource2_raster_path = raster_file.path }
          expect(resource1_raster_path).not_to eq(resource2_raster_path)
        end
      end

      context 'when both resources have the SAME "placeholder://"-prefixed source_uri value' do
        let(:source_uri) { 'placeholder://sound' }
        it 'uses the same raster cache path for each resource' do
          resource1_raster_path = nil
          resource2_raster_path = nil
          resource1.yield_cached_raster(base_type, raster_opts) { |raster_file| resource1_raster_path = raster_file.path }
          resource2.yield_cached_raster(base_type, raster_opts) { |raster_file| resource2_raster_path = raster_file.path }
          expect(resource1_raster_path).to eq(resource2_raster_path)
        end
      end
    end
  end

  context '#with_source_image_file' do
    context "with a railsroot:// path" do
      it "returns the path to an existing file" do
        allow(instance).to receive(:source_uri).and_return('railsroot://spec/fixtures/files/sample-with-transparency.png')

        instance.with_source_image_file do |file|
          expect(Rails.root.join('spec', 'fixtures', 'files', 'sample-with-transparency.png').to_s).to eq(file.path)
        end
      end

      it "raises an error for a file that doesn't exist" do
        allow(instance).to receive(:source_uri).and_return('railsroot://nofile.png')
        expect { instance.with_source_image_file { |_file| } }.to raise_error(Errno::ENOENT)
      end
    end

    context "with a placeholder:// path" do
      it "returns the path to an existing file" do
        allow(instance).to receive(:source_uri).and_return('placeholder://sound')

        instance.with_source_image_file do |file|
          expect(Rails.root.join('app', 'assets', 'images', 'placeholders', 'sound.png').to_s).to eq(file.path)
        end
      end

      it "raises an error for a file that doesn't exist" do
        allow(instance).to receive(:source_uri).and_return('placeholder://nofile')
        expect { instance.with_source_image_file { |_file| } }.to raise_error(Errno::ENOENT)
      end
    end

    context 'with an absolute file:// path' do
      it "returns the path to an existing file" do
        temp_file_path = Dir.tmpdir + '/triclops-test-file.png'
        FileUtils.touch(temp_file_path)
        allow(instance).to receive(:source_uri).and_return('file://' + temp_file_path)

        instance.with_source_image_file do |file|
          expect(temp_file_path).to eq(file.path)
        end
      ensure
        File.unlink(temp_file_path)
      end

      it "raises an error for a file that doesn't exist" do
        allow(instance).to receive(:source_uri).and_return('file:///no/file/here.png')
        expect { instance.with_source_image_file { |_file| } }.to raise_error(Errno::ENOENT)
      end
    end

    it "raises an error for an unsupported protocol" do
      allow(instance).to receive(:source_uri).and_return('abc://what/does/this/protocol/even/mean.png')
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

  context '#iiif_cache_path_for_raster' do
    it 'works as expected for a non-placeholder source_uri' do
      expect(instance.iiif_cache_path_for_raster(base_type, raster_opts)).to eq(
        "#{TRICLOPS[:raster_cache][:directory]}/9f/86/d0/81/"\
        "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08/#{base_type}/iiif/full/full/0/color.png"
      )
    end

    it 'works as expected for a placeholder source_uri' do
      instance.source_uri = 'placeholder://cool'
      expect(instance.iiif_cache_path_for_raster(base_type, raster_opts)).to eq(
        "#{TRICLOPS[:raster_cache][:directory]}/63/0f/dc/84/"\
        "630fdc84e37d2c114ca6afdccb24fdc534bdd5f363745fe26833607fb067a080/#{base_type}/iiif/full/full/0/color.png"
      )
    end
  end

  context '#source_uri_is_placeholder?' do
    it 'returns false when location uri does not start with placeholder://' do
      expect(instance.source_uri_is_placeholder?).to eq(false)
    end

    it 'returns true when location uri starts with placeholder://' do
      instance.source_uri = 'placeholder://cool'
      expect(instance.source_uri_is_placeholder?).to eq(true)
    end
  end

  context 'on save' do
    # it 'automatically extracts missing image properties' do
    #   expect(instance).to receive(:extract_width_and_height_if_missing_or_source_changed!)
    #   expect(instance.save).to eq(true)
    # end
  end
end
