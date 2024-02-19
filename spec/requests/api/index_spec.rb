require 'rails_helper'

RSpec.describe 'show resource', type: :request do
  let(:identifiers) { ['test1', 'test2'] }

  describe 'GET /resources/:id' do
    context 'without authentication' do
      context 'with valid update params' do
        it 'returns a 401 status' do
          FactoryBot.create(:resource, identifier: identifiers[0])
          get '/api/v1/resources/'
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end

    context 'with authentication' do
      it 'returns a list of resources' do
        resources = identifiers.map do |identifier|
          FactoryBot.create(:resource, identifier: identifier)
        end
        get_with_auth '/api/v1/resources'
        expect(response).to have_http_status(:success)
        expected_response_json = {
          'resources' => resources.map do |resource|
            {
              'accessed_at' => nil,
              'created_at' => resource.created_at.to_time.iso8601(3),
              'error_message' => nil,
              'featured_region' => resource.featured_region,
              'height' => resource.height,
              'id' => resources.index(resource) + 1,
              'identifier' => resource.identifier,
              'pcdm_type' => 'Image',
              'source_uri' => resource.source_uri,
              'status' => 'pending',
              'updated_at' => resource.updated_at.to_time.iso8601(3),
              'width' => resource.width
            }
          end,
          'last_page' => true
        }
        expect(JSON.parse(response.body)).to eq(expected_response_json)
      end

      it 'properly filters resources by identifier' do
        resources = identifiers.map do |identifier|
          FactoryBot.create(:resource, identifier: identifier)
        end
        get_with_auth "/api/v1/resources?identifier=#{identifiers[1]}"
        # puts "/api/v1/resources/identifier=#{identifiers[1]}"
        expect(response).to have_http_status(:success)
        resource = resources[1]
        expected_response_json =
          {
            'resources' => [{
              'accessed_at' => nil,
              'created_at' => resource.created_at.to_time.iso8601(3),
              'error_message' => nil,
              'featured_region' => resource.featured_region,
              'height' => resource.height,
              'id' => resources.index(resource) + 1,
              'identifier' => resource.identifier,
              'pcdm_type' => 'Image',
              'source_uri' => resource.source_uri,
              'status' => 'pending',
              'updated_at' => resource.updated_at.to_time.iso8601(3),
              'width' => resource.width
            }],
            'last_page' => true
          }
        expect(JSON.parse(response.body)).to eq(expected_response_json)
      end

      it 'properly filters resources by status' do
        resources = [
          FactoryBot.create(:resource, identifier: identifiers[0]),
          FactoryBot.create(:resource, :ready, identifier: identifiers[1])
        ]
        get_with_auth '/api/v1/resources?status=ready'
        # puts "/api/v1/resources/identifier=#{identifiers[1]}"
        expect(response).to have_http_status(:success)
        resource = resources[1]
        expected_response_json =
          {
            'resources' => [{
              'accessed_at' => nil,
              'created_at' => resource.created_at.to_time.iso8601(3),
              'error_message' => nil,
              'featured_region' => resource.featured_region,
              'height' => resource.height,
              'id' => resources.index(resource) + 1,
              'identifier' => resource.identifier,
              'pcdm_type' => 'Image',
              'source_uri' => resource.source_uri,
              'status' => 'ready',
              'updated_at' => resource.updated_at.to_time.iso8601(3),
              'width' => resource.width
            }],
            'last_page' => true
          }
        expect(JSON.parse(response.body)).to eq(expected_response_json)
      end

      it 'properly recieves a page' do
        resources = identifiers.map do |identifier|
          FactoryBot.create(:resource, identifier: identifier)
        end
        get_with_auth '/api/v1/resources?per_page=1&page=2'
        # puts "/api/v1/resources/identifier=#{identifiers[1]}"
        expect(response).to have_http_status(:success)
        resource = resources[1]
        expected_response_json =
          {
            'resources' => [{
              'accessed_at' => nil,
              'created_at' => resource.created_at.to_time.iso8601(3),
              'error_message' => nil,
              'featured_region' => resource.featured_region,
              'height' => resource.height,
              'id' => resources.index(resource) + 1,
              'identifier' => resource.identifier,
              'pcdm_type' => 'Image',
              'source_uri' => resource.source_uri,
              'status' => 'pending',
              'updated_at' => resource.updated_at.to_time.iso8601(3),
              'width' => resource.width
            }],
            'last_page' => true
          }
        expect(JSON.parse(response.body)).to eq(expected_response_json)
      end
    end
  end
end
