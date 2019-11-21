require 'rails_helper'

RSpec.describe Resource, type: :model do
  let(:identifier) { 'test' }
  let(:location_uri) { 'railsroot://spec/fixtures/files/sample.jpg' }
  let(:width) { 1920 }
  let(:height) { 3125 }
  let(:featured_region) { '320,616,1280,1280' }
  let(:instance) do
    inst = described_class.new({
      identifier: identifier,
      location_uri: location_uri,
      width: width,
      height: height,
      featured_region: featured_region
    })
    inst.accessed_at = DateTime.current
    inst
  end

  context "#as_json" do
    it 'returns the expected hash' do
      created_at = instance.created_at
      updated_at = instance.updated_at
      accessed_at = instance.accessed_at
      expect(
        {
          identifier: identifier,
          featured_region: featured_region,
          location_uri: location_uri,
          width: width,
          height: height,
          created_at: created_at,
          updated_at: updated_at,
          accessed_at: accessed_at
        }
      ).to eq(instance.as_json)
    end
  end
end
