require 'rails_helper'

RSpec.describe Resource, type: :model do
  let(:instance) { FactoryBot.build(:resource) }

  context 'validations' do
    context 'valid object' do
      it 'passes validation' do
        expect(instance).to be_valid
      end
    end

    context 'identifier' do
      it 'must be present' do
        instance.identifier = nil
        instance.save
        expect(instance.errors.attribute_names).to eq([:identifier])
        instance.identifier = ''
        instance.save
        expect(instance.errors.attribute_names).to eq([:identifier])
      end

      it 'is restricted to a max length' do
        instance.identifier = 'a' * 255
        expect(instance.save).to eq(true)
        instance.identifier = 'a' * 256
        instance.save
        expect(instance.errors.attribute_names).to eq([:identifier])
      end
    end

    context 'source_uri' do
      it 'must be readable if present' do
        instance.source_uri = 'file:///does-not-exist'
        instance.save
        expect(instance.errors.attribute_names).to eq([:source_uri])
      end
    end

    context 'featured_region' do
      it 'has an error when a supplied featured_region format is invalid' do
        instance.featured_region = 'zzz'
        expect(instance).not_to be_valid
        expect(instance.errors.attribute_names).to eq([:featured_region])
      end

      it 'has an error if featured_region is blank when a source_uri is present' do
        instance.featured_region = nil
        expect(instance).not_to be_valid
        expect(instance.errors.attribute_names).to eq([:featured_region])
      end
    end

    context 'bad values for standard_width and standard_height fields' do
      before do
        instance.standard_width = standard_width
        instance.standard_height = standard_height
      end

      context 'has errors when standard_width and standard_height are negative' do
        let(:standard_width) { -1 }
        let(:standard_height) { -2 }
        it do
          expect(instance).not_to be_valid
          expect(instance.errors.attribute_names).to include(:standard_width, :standard_height)
        end
      end

      context 'has errors when standard_width and standard_height are zero' do
        let(:standard_width) { 0 }
        let(:standard_height) { 0 }

        it do
          expect(instance).not_to be_valid
          expect(instance.errors.attribute_names).to include(:standard_width, :standard_height)
        end
      end

      context 'has errors when standard_width and standard_height are not integers' do
        let(:standard_width) { 1.5 }
        let(:standard_height) { 2.5 }

        it do
          expect(instance).not_to be_valid
          expect(instance.errors.attribute_names).to include(:standard_width, :standard_height)
        end
      end
    end
  end
end
