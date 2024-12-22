require 'rails_helper'

RSpec.describe Resource, type: :model do
  let(:resource) do
    FactoryBot.create(:resource)
  end

  context "#as_json" do
    it 'returns the expected hash' do
      created_at = resource.created_at
      updated_at = resource.updated_at
      accessed_at = resource.accessed_at
      expect(
        {
          identifier: resource.identifier,
          has_view_limitation: resource.has_view_limitation,
          featured_region: resource.featured_region,
          source_uri: resource.source_uri,
          standard_width: resource.standard_width,
          standard_height: resource.standard_height,
          limited_width: resource.limited_width,
          limited_height: resource.limited_height,
          featured_width: resource.featured_width,
          featured_height: resource.featured_height,
          created_at: resource.created_at,
          updated_at: resource.updated_at,
          accessed_at: resource.accessed_at
        }
      ).to eq(resource.as_json)
    end
  end
end
