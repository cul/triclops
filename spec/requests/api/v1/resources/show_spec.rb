require 'rails_helper'

RSpec.describe "show resource", type: :request do
  let(:identifier) { 'test' }

  describe "GET /resources/:id" do
    it 'returns a 406 not acceptable response for a non-json request' do
      get "/api/v1/resources/#{identifier}.html"
      expect(response).to have_http_status(:not_acceptable)
    end

    it "returns a success response for an existing resource" do
      FactoryBot.create(:resource, identifier: identifier)
      get "/api/v1/resources/#{identifier}.json"
      expect(response).to have_http_status(:success)
    end

    it "returns a 404 not found response for a non-existing resource" do
      get "/api/v1/resources/does-not-exist.json"
      expect(response).to have_http_status(:not_found)
    end
  end
end
