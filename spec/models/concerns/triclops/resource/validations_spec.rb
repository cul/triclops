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

    context 'featured_region format' do
      before { instance.featured_region = 'zzz' }

      it 'has an error when a supplied featured_region format is invalid' do
        expect(instance).not_to be_valid
        expect(instance.errors.attribute_names).to eq([:featured_region])
      end
    end

    context 'bad values for width and height fields' do
      before do
        # For this set of tests, we need to source_uri_changed? return value to false,
        # otherwise the instance will try to re-extract the width and height from
        # the source file and will ignore the values we are supplying in the test.
        allow(instance).to receive(:source_uri_changed?).and_return(false)

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
          # For this test, need to source_uri_changed? return value to false,
          # otherwise the instance will try to re-extract the width and height from
          # the source file and will ignore the values we are supplying in the test.
          allow(instance).to receive(:source_uri_changed?).and_return(false)

          expect(instance).not_to be_valid
          expect(instance.errors.attribute_names).to include(:width, :height)
        end
      end
    end
  end
end
