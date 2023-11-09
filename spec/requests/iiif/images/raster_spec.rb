require 'rails_helper'

RSpec.describe "images#raster", type: :request do
  describe "/iiif/2/sample/region/size/rotation/quality.format" do
    let(:valid_identifier) { 'cool' }
    let(:invalid_identifier) { 'not-cool' }
    let(:valid_raster_url) { "/iiif/2/#{valid_identifier}/full/512,/0/default.jpg" }
    let(:invalid_raster_url) { "/iiif/2/#{invalid_identifier}/full/512,/0/default.jpg" }

    before {
      FactoryBot.create(:resource, :ready, identifier: valid_identifier, pcdm_type: BestType::PcdmTypeLookup::IMAGE)
    }

    context "successful response" do
      let(:config_with_access_stats_enabled) do
        config = TRICLOPS.dup
        config[:raster_cache] = config[:raster_cache].dup
        config[:raster_cache][:access_stats_enabled] = true
        config
      end
      let(:config_with_access_stats_disabled) do
        config = TRICLOPS.dup
        config[:raster_cache] = config[:raster_cache].dup
        config[:raster_cache][:access_stats_enabled] = false
        config
      end

      before { allow_any_instance_of(Iiif::ImagesController).to receive(:handle_ready_resource) }

      it "updates the access stat cache when access stats are enabled" do
        stub_const('TRICLOPS', config_with_access_stats_enabled)
        expect(Triclops::ResourceAccessStatCache.instance).to receive(:add).with(valid_identifier)
        get valid_raster_url
        expect(response).to have_http_status(:success)
      end

      it "does not update the access stat cache when access stats are disabled" do
        stub_const('TRICLOPS', config_with_access_stats_disabled)
        expect(Triclops::ResourceAccessStatCache.instance).not_to receive(:add).with(valid_identifier)
        get valid_raster_url
        expect(response).to have_http_status(:success)
      end
    end

    it "returns a 302 response for raster url when a ready resource does not exist" do
      get invalid_raster_url
      expect(response).to have_http_status(:found)
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
