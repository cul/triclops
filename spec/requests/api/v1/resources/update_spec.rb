require 'rails_helper'

RSpec.describe "update resource", type: :request do
  let(:identifier) { 'update-test' }
  let(:secondary_identifier) { 'update-test-alt-id' }

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

  let!(:resource) { FactoryBot.create(:resource, identifier: identifier, secondary_identifier: secondary_identifier) }

  describe "PATCH /resources/:id" do
    let(:identifier_patch_url) { "/api/v1/resources/#{identifier}.json" }
    let(:secondary_identifier_patch_url) { "/api/v1/resources/#{secondary_identifier}.json" }
    let(:non_existent_identifier_patch_url) { "/api/v1/resources/nope.json" }

    context "with valid update params" do
      it "returns a success response when using the primary identifier in the url" do
        patch identifier_patch_url, params: { resource: valid_update_attributes }
        expect(response).to have_http_status(:success)
      end

      it "returns a success response when using the secondary identifier in the url" do
        patch secondary_identifier_patch_url, params: { resource: valid_update_attributes }
        expect(response).to have_http_status(:success)
      end

      context "when updating identifiers" do
        let(:new_identifier) { 'new-identifier' }
        let(:new_secondary_identifier) { 'new-secondary-identifier' }

        it "allows changing of the identifier for an existing resource" do
          patch identifier_patch_url, params: { resource: { identifier: new_identifier } }
          expect(response).to have_http_status(:success)
          resource.reload
          expect(resource.identifier).to eq(new_identifier)
        end

        it "allows changing of the secondary_identifier for an existing resource" do
          patch identifier_patch_url, params: { resource: { secondary_identifier: new_secondary_identifier } }
          expect(response).to have_http_status(:success)
          resource.reload
          expect(resource.secondary_identifier).to eq(new_secondary_identifier)
        end
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
