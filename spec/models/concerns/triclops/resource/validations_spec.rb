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

    context 'secondary_identifier' do
      it 'when present, must have a minimum length of one character' do
        instance.secondary_identifier = nil
        expect(instance.save).to eq(true)
        instance.secondary_identifier = ''
        instance.save
        expect(instance.errors.attribute_names).to eq([:secondary_identifier])
        instance.secondary_identifier = 'a'
        expect(instance.save).to eq(true)
      end

      it 'is restricted to a max length' do
        instance.secondary_identifier = 'a' * 255
        expect(instance.save).to eq(true)
        instance.secondary_identifier = 'a' * 256
        instance.save
        expect(instance.errors.attribute_names).to eq([:secondary_identifier])
      end
    end

    context 'location_uri' do
      it 'must be present' do
        instance.location_uri = nil
        instance.save
        expect(instance.errors.attribute_names).to eq([:location_uri])
        instance.location_uri = ''
        instance.save
        expect(instance.errors.attribute_names).to eq([:location_uri])
      end
    end

    context 'featured_region format' do
      before { instance.featured_region = 'zzz' }

      it 'has an error when a supplied featured_region format is invalid' do
        expect(instance).not_to be_valid
        expect(instance.errors.attribute_names).to eq([:featured_region])
      end
    end

    context 'width and height fields' do
      before do
        instance.width = width
        instance.height = height
      end

      context 'has errors when width and height are negative' do
        let(:width) { -1 }
        let(:height) { -2 }
        it do
          expect(instance).not_to be_valid
          expect(instance.errors.attribute_names).to include(:width, :height)
        end
      end

      context 'has errors when width and height are zero' do
        let(:width) { 0 }
        let(:height) { 0 }

        it do
          expect(instance).not_to be_valid
          expect(instance.errors.attribute_names).to include(:width, :height)
        end
      end

      context 'has errors when width and height are not integers' do
        let(:width) { 1.5 }
        let(:height) { 2.5 }

        it do
          expect(instance).not_to be_valid
          expect(instance.errors.attribute_names).to include(:width, :height)
        end
      end
    end

    context 'uniqueness of identifiers' do
      it 'fails to save when the identifier is equal to the secondary_identifier' do
        instance.secondary_identifier = instance.identifier
        instance.save
        expect(instance.errors.attribute_names).to eq([:identifier])
      end

      it 'fails to save if an identifier is already taken' do
        FactoryBot.create(:resource, identifier: instance.identifier)
        instance.save
        expect(instance.errors.attribute_names).to eq([:identifier])
      end

      it 'fails to save if a secondary identifier is already taken' do
        FactoryBot.create(:resource, secondary_identifier: instance.secondary_identifier)
        instance.save
        expect(instance.errors.attribute_names).to eq([:secondary_identifier])
      end

      it 'fails to save if new identifier conflicts with an existing secondary identifier' do
        FactoryBot.create(:resource, secondary_identifier: instance.identifier)
        instance.save
        expect(instance.errors.attribute_names).to eq([:identifier])
      end

      it 'fails to save if new secondary identifier conflicts with an existing identifier' do
        FactoryBot.create(:resource, identifier: instance.secondary_identifier)
        instance.save
        expect(instance.errors.attribute_names).to eq([:secondary_identifier])
      end
    end

    context 'readable location uri' do
      it 'fails to save when the location_uri is not a readable file' do
        instance.location_uri = 'file:///does-not-exist'
        instance.save
        expect(instance.errors.attribute_names).to eq([:location_uri])
      end
    end
  end
end
