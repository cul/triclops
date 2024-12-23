require 'rails_helper'

RSpec.describe Resource, type: :model do
  let(:base_type) { Triclops::Iiif::Constants::BASE_TYPE_STANDARD }

  let(:pending_resource) { FactoryBot.create(:resource, identifier: 'pending-resource') }
  let(:ready_resource) { FactoryBot.create(:resource, :ready, identifier: 'ready-resource') }
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
    let(:identifier) { 'some-identifier' }
    let(:new_instance) do
      described_class.new(
        identifier: identifier,
        has_view_limitation: false,
        source_uri: 'railsroot:///spec/fixtures/files/sample.jpg',
        standard_width: 1920,
        standard_height: 3125,
        featured_region: '320,616,1280,1280',
        pcdm_type: BestType::PcdmTypeLookup::IMAGE
      )
    end

    it 'successfully creates a new instance and sets up appropriate fields' do
      expect(new_instance).to be_a(described_class)
      expect(new_instance.identifier).to eq(identifier)
      expect(new_instance.has_view_limitation).to eq(false)
      expect(new_instance.source_uri).to eq('railsroot:///spec/fixtures/files/sample.jpg')
      expect(new_instance.standard_width).to eq(1920)
      expect(new_instance.standard_height).to eq(3125)
      expect(new_instance.featured_region).to eq('320,616,1280,1280')
      expect(new_instance.pcdm_type).to eq(BestType::PcdmTypeLookup::IMAGE)
      expect(new_instance.status).to eq('pending')
    end
  end

  context 'validation' do
    it 'calls wait_for_source_uri_if_local_disk_file before validation' do
      expect(ready_resource).to receive(:wait_for_source_uri_if_local_disk_file)
      ready_resource.valid?
    end
  end

  context '#save' do
    it 'calls switch_to_pending_state_if_core_properties_changed! before save' do
      expect(ready_resource).to receive(:switch_to_pending_state_if_core_properties_changed!)
      ready_resource.save
    end

    it 'calls queue_base_derivative_generation_if_pending after save' do
      expect(ready_resource).to receive(:queue_base_derivative_generation_if_pending)
      ready_resource.save
    end
  end

  context '#destroy' do
    it 'calls delete_filesystem_cache! after destroy' do
      expect(ready_resource).to receive(:delete_filesystem_cache!).and_call_original
      ready_resource.destroy
    end
  end

  context '#delete_filesystem_cache!' do
    it 'performs the expected deletion operation' do
      expect(FileUtils).to receive(:rm_rf).with(Triclops::RasterCache.instance.cache_directory_for_identifier(ready_resource.identifier))
      ready_resource.delete_filesystem_cache!
    end
  end

  context '#queue_base_derivative_generation_if_pending' do
    it 'queues generation for a pending resource' do
      expect(CreateBaseDerivativesJob).to receive(:perform_later).with(pending_resource.identifier)
      pending_resource.queue_base_derivative_generation_if_pending
    end

    it 'does not queue generation for a non-pending resource' do
      expect(CreateBaseDerivativesJob).not_to receive(:perform_later)
      ready_resource.queue_base_derivative_generation_if_pending
    end
  end

  context '#switch_to_pending_state_if_core_properties_changed!' do
    let(:new_unsaved_resource) { FactoryBot.create(:resource) }
    it 'does not change the status for a new record' do
      expect(new_unsaved_resource).not_to receive(:status=)
      new_unsaved_resource.switch_to_pending_state_if_core_properties_changed!
    end

    it 'does not change the status for a persisted resource if none of its properties have changed since it was last saved' do
      expect(ready_resource).not_to receive(:status=)
      ready_resource.switch_to_pending_state_if_core_properties_changed!
    end

    it 'changes the status for a persisted resource if its source_uri has changed' do
      expect(ready_resource).to receive(:status=).with(:pending)
      ready_resource.source_uri = ready_resource.source_uri.sub('sample.jpg', 'sample2.jpg')
      ready_resource.switch_to_pending_state_if_core_properties_changed!
    end

    it 'changes the status for a persisted resource if its featured_region has changed' do
      expect(ready_resource).to receive(:status=).with(:pending)
      ready_resource.featured_region = '10,10,200,200'
      ready_resource.switch_to_pending_state_if_core_properties_changed!
    end

    it 'changes the status for a persisted resource if its pcdm_type has changed' do
      expect(ready_resource).to receive(:status=).with(:pending)
      ready_resource.pcdm_type = BestType::PcdmTypeLookup::VIDEO
      ready_resource.switch_to_pending_state_if_core_properties_changed!
    end
  end

  context '#yield_uncached_raster' do
    let(:tmp_file_path) { Rails.root.join('tmp', 'test-tmp-file.png').to_s }
    before do
      # For these tests, we always want to receive the same tmp_file_path
      allow(Resource).to receive(:generate_raster_tempfile_path).and_return(tmp_file_path)
    end

    it 'generates a raster file and automatically deletes that raster file after yielding' do
      expect(Triclops::Raster).to receive(:generate).with(
        Triclops::Utils::UriUtils.location_uri_to_file_path(ready_resource.source_uri),
        tmp_file_path,
        raster_opts
      ).and_call_original

      ready_resource.yield_uncached_raster(raster_opts) do |raster_file|
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
      ready_resource.delete_filesystem_cache!
    end

    it 'when an existing raster file does not exist, generates and caches a new raster file and yields that new raster file' do
      expected_cache_path = Triclops::RasterCache.instance.iiif_cache_path_for_raster(base_type, ready_resource.identifier, raster_opts)
      expect(Triclops::Raster).to receive(:generate).with(
        Triclops::Utils::UriUtils.location_uri_to_file_path(ready_resource.source_uri),
        expected_cache_path,
        raster_opts
      ).and_call_original

      ready_resource.yield_cached_raster(base_type, raster_opts) do |raster_file|
        expect(raster_file.path).to eq(expected_cache_path)
      end
    end

    it 'yields the same raster file when called multiple times, and does not regenerate the file for the second yield' do
      # Generate the raster
      path_from_first_yield = nil
      ready_resource.yield_cached_raster(base_type, raster_opts) do |raster_file|
        path_from_first_yield = raster_file.path
      end

      # Then call yield_cached_raster again to return the already-generated raster
      expect(Triclops::Raster).not_to receive(:generate)
      ready_resource.yield_cached_raster(base_type, raster_opts) do |raster_file|
        expect(path_from_first_yield).to eq(raster_file.path)
      end
    end

    context 'when two different resources have different identifiers, but the same source_uri value' do
      let(:ready_resource1) do
        FactoryBot.create(:resource, source_uri: source_uri)
      end
      let(:ready_resource2) do
        FactoryBot.create(:resource, source_uri: ready_resource1.source_uri)
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
        ready_resource1.delete_filesystem_cache!
        ready_resource2.delete_filesystem_cache!
      end

      context 'when both resources have the same NON-"placeholder:///"-prefixed source_uri value' do
        let(:source_uri) { "railsroot:///#{File.join('spec', 'fixtures', 'files', 'sample.jpg')}" }
        it  'results in two different raster cache paths for each resource '\
            '(because we want to be able to clear each cache independently)' do
          ready_resource1_raster_path = nil
          ready_resource2_raster_path = nil
          ready_resource1.yield_cached_raster(base_type, raster_opts) { |raster_file| ready_resource1_raster_path = raster_file.path }
          ready_resource2.yield_cached_raster(base_type, raster_opts) { |raster_file| ready_resource2_raster_path = raster_file.path }
          expect(ready_resource1_raster_path).not_to eq(ready_resource2_raster_path)
        end
      end

      context 'when both resources have the SAME "placeholder:///"-prefixed source_uri value' do
        let(:source_uri) { 'placeholder:///sound' }
        it 'uses the same raster cache path for each resource' do
          ready_resource1_raster_path = nil
          ready_resource2_raster_path = nil
          ready_resource1.yield_cached_raster(base_type, raster_opts) { |raster_file| ready_resource1_raster_path = raster_file.path }
          ready_resource2.yield_cached_raster(base_type, raster_opts) { |raster_file| ready_resource2_raster_path = raster_file.path }
          expect(ready_resource1_raster_path).to eq(ready_resource2_raster_path)
        end
      end
    end
  end

  context '#with_source_image_file' do
    context "with a railsroot:/// path" do
      it "returns the path to an existing file" do
        allow(ready_resource).to receive(:source_uri).and_return('railsroot:///spec/fixtures/files/sample-with-transparency.png')

        ready_resource.with_source_image_file do |file|
          expect(Rails.root.join('spec', 'fixtures', 'files', 'sample-with-transparency.png').to_s).to eq(file.path)
        end
      end

      it "raises an error for a file that doesn't exist" do
        allow(ready_resource).to receive(:source_uri).and_return('railsroot:///nofile.png')
        expect { ready_resource.with_source_image_file { |_file| } }.to raise_error(Errno::ENOENT)
      end
    end

    context "with a placeholder:/// path" do
      it "returns the path to an existing file" do
        allow(ready_resource).to receive(:source_uri).and_return('placeholder:///sound')

        ready_resource.with_source_image_file do |file|
          expect(Rails.root.join('app', 'assets', 'images', 'placeholders', 'sound.png').to_s).to eq(file.path)
        end
      end

      it "raises an error for a file that doesn't exist" do
        allow(ready_resource).to receive(:source_uri).and_return('placeholder:///nofile')
        expect { ready_resource.with_source_image_file { |_file| } }.to raise_error(Errno::ENOENT)
      end
    end

    context 'with a file:// path' do
      it "returns the path to an existing file" do
        temp_file_path = Dir.tmpdir + '/triclops-test-file.png'
        FileUtils.touch(temp_file_path)
        allow(ready_resource).to receive(:source_uri).and_return('file://' + temp_file_path)

        ready_resource.with_source_image_file do |file|
          expect(temp_file_path).to eq(file.path)
        end
      ensure
        File.unlink(temp_file_path)
      end

      it "raises an error for a file that doesn't exist" do
        allow(ready_resource).to receive(:source_uri).and_return('file:///no/file/here.png')
        expect { ready_resource.with_source_image_file { |_file| } }.to raise_error(Errno::ENOENT)
      end
    end

    it "raises an error for an unsupported protocol" do
      allow(ready_resource).to receive(:source_uri).and_return('abc:///what/does/this/protocol/even/mean.png')
      expect { ready_resource.with_source_image_file { |_file| } }.to raise_error(Errno::ENOENT)
    end
  end

  context '#source_uri_is_readable?' do
    it 'returns true when the source uri file is readable' do
      expect(ready_resource.source_uri_is_readable?).to eq(true)
    end

    it 'returns true when the source uri file is not readable' do
      ready_resource.source_uri = 'file:///this/file/does/not/exist.txt'
      expect(ready_resource.source_uri_is_readable?).to eq(false)
    end
  end

  context '#raster_exists?' do
    it 'returns true when a raster file exists' do
      allow(File).to receive(:exist?).with(
        File.join(
          Triclops::RasterCache.instance.cache_directory_for_identifier(ready_resource.identifier),
          "standard/iiif/full/full/0/color.png"
        )
      ).and_return(true)
      expect(ready_resource.raster_exists?(base_type, raster_opts)).to eq(true)
    end

    it 'returns false when a raster file does not exist' do
      expect(ready_resource.raster_exists?(base_type, raster_opts)).to eq(false)
    end
  end

  context '#placeholder_identifier_for_pcdm_type' do

    {
      BestType::PcdmTypeLookup::AUDIO => 'placeholder:sound',
      BestType::PcdmTypeLookup::VIDEO => 'placeholder:moving_image',
      BestType::PcdmTypeLookup::TEXT => 'placeholder:text',
      BestType::PcdmTypeLookup::PAGE_DESCRIPTION => 'placeholder:text',
      BestType::PcdmTypeLookup::SOFTWARE => 'placeholder:software',
      BestType::PcdmTypeLookup::FONT => 'placeholder:unavailable',
    }.each do |pcdm_type, expected_placeholder|
      it "returns the expected value for a resource with a pcdm_type of #{pcdm_type}" do
        ready_resource.pcdm_type = pcdm_type
        expect(ready_resource.placeholder_identifier_for_pcdm_type).to eq(expected_placeholder)
      end
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
      expect(ready_resource.iiif_cache_path_for_raster(base_type, raster_opts)).to eq(
        "#{TRICLOPS[:raster_cache][:directory]}/62/60/d5/01/"\
        "6260d501613040c7993755c92621e0a90abc64e3a81006259e6532a785d5072c/#{base_type}/iiif/full/full/0/color.png"
      )
    end

    it 'works as expected for a placeholder source_uri' do
      ready_resource.source_uri = 'placeholder:///cool'
      expect(ready_resource.iiif_cache_path_for_raster(base_type, raster_opts)).to eq(
        "#{TRICLOPS[:raster_cache][:directory]}/14/31/7a/33/"\
        "14317a3348a284ab4de0eee4c049370b93f709c9661c200d569902b959224ae1/#{base_type}/iiif/full/full/0/color.png"
      )
    end
  end

  context '#source_uri_is_placeholder?' do
    it 'returns false when location uri does not start with placeholder:///' do
      expect(ready_resource.source_uri_is_placeholder?).to eq(false)
    end

    it 'returns true when location uri starts with placeholder:///' do
      ready_resource.source_uri = 'placeholder:///cool'
      expect(ready_resource.source_uri_is_placeholder?).to eq(true)
    end
  end

  context '#wait_for_source_uri_if_local_disk_file' do
    it 'returns immediately (and does not sleep) if the file exists' do
      expect(Kernel).not_to receive(:sleep)
      ready_resource.wait_for_source_uri_if_local_disk_file
    end

    it 'waits and performs multiple checks over time if the files does not exist' do
      ready_resource.source_uri = 'file:///this/file/does/not/exist.tiff'
      expect(File).to receive(:exist?).exactly(5).times.and_call_original
      expect(ready_resource).to receive(:sleep).exactly(5).times
      ready_resource.wait_for_source_uri_if_local_disk_file
    end
  end

  context '#raise_exception_if_base_derivative_dependency_missing!' do
    before do
      ready_resource.source_uri = nil
      ready_resource.featured_region = nil
    end
    it 'raises an exception under the expected conditions' do
      expect { ready_resource.raise_exception_if_base_derivative_dependency_missing! }.to raise_error(
        Triclops::Exceptions::MissingBaseImageDependencyException
      )
    end
  end

  context '.placeholder_resource_for' do
    let(:valid_placeholder_resource_identifier) { 'placeholder:file' }
    let(:invalid_placeholder_resource_identifier) { 'placeholder:banana' }

    it 'creates the expected resource when a valid placeholder_resource_identifier is given' do
      res = described_class.placeholder_resource_for(valid_placeholder_resource_identifier)
      expect(res).to be_a(Resource)
      expect(res.as_json).to eq({
        accessed_at: nil,
        created_at: nil,
        featured_height: 768,
        featured_region: "0,0,2292,2292",
        featured_width: 768,
        has_view_limitation: false,
        identifier: "placeholder:file",
        limited_height: 768,
        limited_width: 768,
        source_uri: "placeholder:///file",
        standard_height: 2292,
        standard_width: 2292,
        updated_at: res.updated_at
      })
    end

    it 'raises an exception if an unsupported placeholder_resource_identifier is given' do
      expect {
        described_class.placeholder_resource_for(invalid_placeholder_resource_identifier)
      }.to raise_error(ArgumentError)
    end
  end
end
