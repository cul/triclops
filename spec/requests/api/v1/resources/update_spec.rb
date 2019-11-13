require 'rails_helper'

RSpec.describe "update resource", type: :request do
  let(:identifier) { 'update-test' }

  let(:valid_update_attributes) {
    {
      width: 2000
    }
  }

  let(:invalid_update_attributes) {
    {
      width: 'string'
    }
  }

  describe "PATCH /resources/:id" do
    let(:patch_url) { "/api/v1/resources/#{identifier}.json" }
    it "returns a success response for a valid attribute update" do
      FactoryBot.create(:resource, identifier: identifier)
      patch patch_url, params: { resource: valid_update_attributes }
      expect(response).to have_http_status(:success)
    end

    it "returns a 400 unprocessable entity response for an invalid attribute update" do
      FactoryBot.create(:resource, identifier: identifier)
      patch patch_url, params: { resource: invalid_update_attributes }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
