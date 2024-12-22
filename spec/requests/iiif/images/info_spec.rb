require 'rails_helper'

RSpec.describe 'images#info', type: :request do
  describe '/iiif/2/:identifier/info.json' do
    let(:base_type) { Triclops::Iiif::Constants::BASE_TYPE_STANDARD }
    let(:ready_identifier) { 'ready-resource' }
    let(:ready_info_url) { "/iiif/2/#{base_type}/#{ready_identifier}/info.json" }
    let!(:ready_resource) { FactoryBot.create(:resource, :ready, identifier: ready_identifier) }

    it "returns a successful response (with CORS header) for a ready resource info url" do
      get ready_info_url
      expect(response).to have_http_status(:success)
      expect(response.headers['Access-Control-Allow-Origin']).to eq('*')
    end

    context "when a resource exists, but does not have a ready status" do
      let(:pending_identifier) { 'pending-resource' }
      let(:pending_info_url) { "/iiif/2/#{base_type}/#{pending_identifier}/info.json" }
      let!(:pending_resource) { FactoryBot.create(:resource, identifier: pending_identifier) }

      it "returns a 302 response for info url, and redirects to a placeholder" do
        get pending_info_url
        expect(response).to have_http_status(:found)
        expect(response.headers['Location']).to end_with('/iiif/2/standard/placeholder:unavailable/info.json')
      end
    end

    context "when a resource does not exist" do
      let(:non_existent_identifier) { 'non_existent-resource' }
      let(:non_existent_info_url) { "/iiif/2/#{base_type}/#{non_existent_identifier}/info.json" }

      it "returns a 302 response for info url, and redirects to a placeholder" do
        get non_existent_info_url
        expect(response).to have_http_status(:found)
        expect(response.headers['Location']).to end_with('/iiif/2/standard/placeholder:unavailable/info.json')
      end
    end
  end
end
