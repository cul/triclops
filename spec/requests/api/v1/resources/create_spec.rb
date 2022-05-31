require 'rails_helper'

RSpec.describe "create resource", type: :request do
  let(:valid_create_attributes) do
    {
      identifier: 'create-test',
      secondary_identifier: 'create-test-alt-id',
      location_uri: 'railsroot://spec/fixtures/files/sample.jpg',
      featured_region: '320,616,1280,1280'
    }
  end

  let(:invalid_create_attributes) {
    {
      identifier: 12_345,
      location_uri: true,
      width: 'string',
      height: 'another string',
      featured_region: 42
    }
  }

  describe "POST /resources" do
    it "returns a success response for valid attributes" do
      post "/api/v1/resources.json", params: { resource: valid_create_attributes }
      expect(response).to have_http_status(:success)
    end

    it "returns a 400 bad request response for invalid attributes" do
      post "/api/v1/resources.json", params: { resource: invalid_create_attributes }
      expect(response).to have_http_status(:bad_request)
    end
  end
end
