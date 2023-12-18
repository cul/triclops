require 'rails_helper'

RSpec.describe 'Create or replace', type: :request do
  let(:valid_update_attributes) do
    {
      featured_region: '20,40,10,10',
      pcdm_type: BestType::PcdmTypeLookup::IMAGE
    }
  end

  let(:invalid_update_attributes) do
    {
      featured_region: 'a,b'
    }
  end

  let(:resource) { FactoryBot.create(:resource, identifier: 'update-test') }
  let(:identifier) { resource.identifier }

  describe 'PUT /resources/:id' do
    let(:identifier_put_url) { "/api/v1/resources/#{identifier}.json" }
    let(:non_existent_identifier_put_url) { '/api/v1/resources/nope.json' }

    context 'without authentication' do
      context 'with valid update params' do
        it 'returns a 401 status' do
          put identifier_put_url, params: { resource: valid_update_attributes }
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end

    context 'with authentication' do
      context 'with valid update params' do
        it 'for a non-existent identifier, creates a resource and returns a 201 created response' do
          put_with_auth non_existent_identifier_put_url, params: { resource: valid_update_attributes }
          expect(response).to have_http_status(:created)
        end

        it 'for a resource that already exists, returns a 200 success response' do
          put_with_auth identifier_put_url, params: { resource: valid_update_attributes }
          expect(response).to have_http_status(:success)
        end
      end

      it 'with invalid update params, returns a 400 bad_request entity response' do
        put_with_auth identifier_put_url, params: { resource: invalid_update_attributes }
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
