require 'rails_helper'

RSpec.describe "images#test_viewer", type: :request do
  describe "http://localhost:3000/iiif/2/test_viewer/:identifier" do
    let(:valid_identifier) { 'cool' }
    let(:invalid_identifier) { 'not-cool' }
    let(:valid_test_viewer_url) { "/iiif/2/test_viewer/#{valid_identifier}" }
    let(:invalid_test_viewer_url) { "/iiif/2/test_viewer/#{invalid_identifier}" }

    before {
      FactoryBot.create(:resource, identifier: valid_identifier)
    }

    it "returns a successful response for a valid test_viewer url" do
      get valid_test_viewer_url
      expect(response).to have_http_status(:success)
    end

    it "returns a 404 response for test_viewer url when resource does not exist" do
      get invalid_test_viewer_url
      expect(response).to have_http_status(:not_found)
    end
  end
end
