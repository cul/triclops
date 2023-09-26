require 'rails_helper'

RSpec.describe 'application#home', type: :request do
  describe '/' do
    it "returns a successful response that includes the application version" do
      get '/'
      expect(response).to have_http_status(:success)
      expect(response.body).to include(APP_VERSION)
    end
  end
end
