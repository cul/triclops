require 'rails_helper'

RSpec.describe "update resource", type: :request do
  let(:identifier) { 'delete-test' }

  describe "DELETE /resources/:id" do
    let(:delete_url) { "/api/v1/resources/#{identifier}.json" }
    it "destroys the specified resource" do
      FactoryBot.create(:resource, identifier: identifier)
      expect {
        delete delete_url
      }.to change(Resource, :count).by(-1)
      expect(response).to have_http_status(:success)
    end

    it 'returns a 422 unprocessable_entity response when deletion is unsuccessful' do
      allow_any_instance_of(Resource).to receive(:destroy).and_return(false)
      FactoryBot.create(:resource, identifier: identifier)
      delete delete_url
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
