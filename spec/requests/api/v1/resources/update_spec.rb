require 'rails_helper'

RSpec.describe "update resource", type: :request do
  let(:valid_update_attributes) do
    {
      featured_region: '20,40,10,10'
    }
  end

  let(:invalid_update_attributes) do
    {
      featured_region: 'a,b'
    }
  end

  let(:resource) { FactoryBot.create(:resource, identifier: 'update-test', pcdm_type: BestType::PcdmTypeLookup::IMAGE) }
  let(:identifier) { resource.identifier }

  describe "PATCH /resources/:id" do
    let(:identifier_patch_url) { "/api/v1/resources/#{identifier}.json" }
    let(:non_existent_identifier_patch_url) { "/api/v1/resources/nope.json" }

    context "with valid update params" do
      it "returns a success response when using the primary identifier in the url" do
        patch identifier_patch_url, params: { resource: valid_update_attributes }
        expect(response).to have_http_status(:success)
      end
    end

    it "with valid update params, returns a 400 bad_request entity response" do
      patch identifier_patch_url, params: { resource: invalid_update_attributes }
      expect(response).to have_http_status(:bad_request)
    end

    it "for a non-existent identifier, returns a 404 not_found entity response" do
      patch non_existent_identifier_patch_url, params: { resource: valid_update_attributes }
      expect(response).to have_http_status(:not_found)
    end
  end
end
