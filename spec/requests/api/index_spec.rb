require 'rails_helper'

RSpec.describe "show resource", type: :request do
  let(:identifiers) { ['test1', 'test2'] }

  describe "GET /resources/:id" do
    context 'without authentication' do
      context 'with valid update params' do
        it 'returns a 401 status' do
          FactoryBot.create(:resource, identifier: identifier)
          get "/api/v1/resources/"
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end

    context 'with authentication' do
      it 'returns a 406 not acceptable response for a non-json request' do
        get_with_auth "/api/v1/resources/"
        expect(response).to have_http_status(:not_acceptable)
      end

      it "returns a list of resources", focus: true do
        resources = identifiers.map do |identifier|
          FactoryBot.create(:resource, identifier: identifier)
        end
        get_with_auth "/api/v1/resources"
        expect(response).to have_http_status(:success)
        expected_response_json = resources.map do |resource|
          {
            'accessed_at' => nil,
            'created_at' => resource.created_at.to_time.iso8601(3),
            'featured_region' => resource.featured_region,
            'height' => resource.height,
            'identifier' => resource.identifier,
            'source_uri' => resource.source_uri,
            'updated_at' => resource.updated_at.to_time.iso8601(3),
            'width' => resource.width
          }
        end
        expect(JSON.parse(response.body)).to eq(expected_response_json)
      end
    end
  end
end
