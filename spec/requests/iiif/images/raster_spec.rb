require 'rails_helper'

RSpec.describe "images#raster", type: :request do
  describe "/iiif/2/sample/region/size/rotation/quality.format" do
    let(:valid_identifier) { 'cool' }
    let(:invalid_identifier) { 'not-cool' }
    let(:valid_raster_url) { "/iiif/2/#{valid_identifier}/featured/512,/0/default.jpg" }
    let(:invalid_raster_url) { "/iiif/2/#{invalid_identifier}/featured/512,/0/default.jpg" }

    before {
      FactoryBot.create(:resource, identifier: valid_identifier)
    }

    context "successful response" do
      let(:cache_enabled_triclops_config) do
        config = TRICLOPS.dup
        config[:raster_cache] = config[:raster_cache].dup
        config[:raster_cache][:enabled] = true
        config
      end
      let(:cache_disabled_triclops_config) do
        config = TRICLOPS.dup
        config[:raster_cache] = config[:raster_cache].dup
        config[:raster_cache][:enabled] = false
        config
      end
      it "returns a successful response for a valid info url when caching is enabled, and adds the identifier to the ResourceAccessCache" do
        stub_const('TRICLOPS', cache_enabled_triclops_config)
        expect(Triclops::ResourceAccessCache.instance).to receive(:add).with(valid_identifier)
        get valid_raster_url
        expect(response).to have_http_status(:success)
      end

      it "returns a successful response for a valid info url when caching is disabled" do
        stub_const('TRICLOPS', cache_disabled_triclops_config)
        get valid_raster_url
        expect(response).to have_http_status(:success)
      end
    end

    it "returns a 404 response for raster url when resource does not exist" do
      get invalid_raster_url
      expect(response).to have_http_status(:not_found)
    end

    context "existing resource, but bad iiif url params" do
      it "bad region" do
        get "/iiif/2/#{valid_identifier}/zzzzzzzzzzzzzzz/512,/0/default.jpg"
        expect(response).to have_http_status(:bad_request)
      end
      it "bad size" do
        get "/iiif/2/#{valid_identifier}/square/zzzzzzzzzzzzzz/0/default.jpg"
        expect(response).to have_http_status(:bad_request)
      end
      it "bad rotation" do
        get "/iiif/2/#{valid_identifier}/square/!256,256/zzzzzzzzzzzzzz/default.jpg"
        expect(response).to have_http_status(:bad_request)
      end
      it "bad quality" do
        get "/iiif/2/#{valid_identifier}/square/!256,256/0/cool.jpg"
        expect(response).to have_http_status(:bad_request)
      end

      it "unsupported format" do
        get "/iiif/2/#{valid_identifier}/square/!256,256/0/default.zip"
        expect(response).to have_http_status(:bad_request)
      end

      it "unsupported positive rotation" do
        get "/iiif/2/#{valid_identifier}/square/!256,256/3/default.jpg"
        expect(response).to have_http_status(:bad_request)
      end

      it "unsupported negative rotation (i.e. ANY negative rotation)" do
        # Note: We don't currently support negative rotation values because Imogen doesn't.
        get "/iiif/2/#{valid_identifier}/square/!256,256/-90/default.jpg"
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
