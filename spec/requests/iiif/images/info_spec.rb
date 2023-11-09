require 'rails_helper'

RSpec.describe 'images#info', type: :request do
  describe '/iiif/2/:identifier/info.json' do
    let(:valid_identifier) { 'cool' }
    let(:invalid_identifier) { 'not-cool' }
    let(:valid_info_url) { "/iiif/2/#{valid_identifier}/info.json" }
    let(:invalid_info_url) { "/iiif/2/#{invalid_identifier}/info.json" }

    before {
      FactoryBot.create(:resource, :ready, identifier: valid_identifier, pcdm_type: BestType::PcdmTypeLookup::IMAGE)
    }

    it "returns a successful response for a valid info url, with CORS header" do
      get valid_info_url
      expect(response).to have_http_status(:success)
      expect(response.headers['Access-Control-Allow-Origin']).to eq('*')
    end

    it "returns a 302 response for info url when resource does not exist" do
      get invalid_info_url
      expect(response).to have_http_status(:found)
    end
  end
end
