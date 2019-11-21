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

  context 'validations' do
    context 'valid object' do
      it 'passes validation' do
        expect(instance).to be_valid
      end
    end

    context 'presence' do
      let(:identifier) { nil }
      let(:location_uri) { nil }
      let(:width) { nil }
      let(:height) { nil }

      it 'has errors when required fields are missing' do
        expect(instance).not_to be_valid
        expect(instance.errors.keys).to include(:identifier, :location_uri, :width, :height)
      end
    end

    context 'featured_region format' do
      let(:featured_region) { 'nooooooooooooooooo' }
      it 'has an error when featured_region format is invalid' do
        expect(instance).not_to be_valid
        expect(instance.errors.keys).to eq([:featured_region])
      end
    end

    context 'width and height fields' do
      context 'has errors when width and height are negative' do
        let(:width) { -1 }
        let(:height) { -2 }
        it do
          expect(instance).not_to be_valid
          expect(instance.errors.keys).to include(:width, :height)
        end
      end

      context 'has errors when width and height are zero' do
        let(:width) { 0 }
        let(:height) { 0 }
        it do
          expect(instance).not_to be_valid
          expect(instance.errors.keys).to include(:width, :height)
        end
      end

      context 'has errors when width and height are not integers' do
        let(:width) { 1.5 }
        let(:height) { 2.5 }
        it do
          expect(instance).not_to be_valid
          expect(instance.errors.keys).to include(:width, :height)
        end
      end
    end
  end
end
