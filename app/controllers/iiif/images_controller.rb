class Iiif::ImagesController < ApplicationController
  include ActionController::Live
  include Triclops::Iiif::ImagesController::Schemas
  include Triclops::Iiif::ImagesController::Sizing

  ALLOWED_FORMATS = {
    'png' => 'image/png',
    'jpg' => 'image/jpeg'
  }.freeze
  ALLOWED_QUALITIES = ['default', 'color', 'gray', 'bitonal'].freeze
  ALLOWED_ROTATIONS = [0, 90, 180, 270].freeze
  RECOMMENDED_SIZES = [256, 512, 1024, 1280].freeze
  TILE_SIZE = 512
  # Note: not supporting 'square' right now because Imogen doesn't support square
  ALLOWED_REGIONS = /full|featured|\d+,\d+,\d+,\d+|pct:\d+,\d+,\d+,\d+/
  ALLOWED_SIZES = /full|max|\d+,|,\d+|pct:\d+|\d+,\d+|!\d+,\d+/

  before_action :add_cors_header!, only: [:info]
  before_action :set_resource_or_handle_not_found, only: [:info, :raster, :test_viewer]

  def info
    render json: @resource.iiif_info(
      iiif_info_url(@resource.identifier)[0...-10], # chop off last 10 characters to remove "/info.json"
      @resource.width,
      @resource.height,
      RECOMMENDED_SIZES.map { |size| closest_size(size, @resource.width, @resource.height) },
      ALLOWED_FORMATS.keys,
      ALLOWED_QUALITIES,
      TILE_SIZE
    )
  end

  # GET /iiif/2/:identifier/:region/:size/:rotation/:quality.(:format)
  # e.g. /iiif/2/sample/full/full/0/default.png
  def raster
    # Validate params and coerce to appropriate types
    schema_call_result = raster_params_schema(ALLOWED_REGIONS, ALLOWED_SIZES, ALLOWED_ROTATIONS, ALLOWED_QUALITIES).call(raster_params.to_h)

    if schema_call_result.errors.present?
      error_messages = schema_call_result.errors(full: true).messages.map(&:text)
      render json: { errors: error_messages }, status: :bad_request
      return
    end

    # :identifier isn't part of our "raster opts"
    raster_opts = schema_call_result.to_h.except(:identifier)

    # Whenever a valid resource is requested, cache the Resource identifier in
    # our ResourceAccessCache. This cache will be periodically flushed to the
    # Resource database (by a separate process) so that many access time updates
    # are done in batch (and do not slow down individual Raster requests).
    # We're keeping track of access time so that when our Raster cache gets full
    # and we want to clear out old cached Raster images, we know which frequently
    # accessed cache items should be kept.
    # Note: We only need to cache access times if caching is enabled. Resource
    # access time doesn't matter if we're not caching anything.
    Triclops::ResourceAccessCache.instance.add(@resource.identifier) if TRICLOPS[:raster_cache][:enabled]

    @resource.raster(raster_opts, TRICLOPS[:raster_cache][:enabled]) do |raster_file|
      send_raster_file(raster_file, raster_opts, @resource.updated_at)
    end
  end

  def test_viewer; end

  private

    def raster_params
      params.permit(:version, :identifier, :region, :size, :rotation, :quality, :format, :download)
    end

    def set_resource_or_handle_not_found
      identifier = params[:identifier]
      return if (
        @resource = Resource.find_by(identifier: identifier)
      )

      render json: { errors: ["Could not find resource with identifier: #{identifier}"] }, status: :not_found
    end

    def raster_send_file_options(download, format)
      {
        disposition: download ? 'attachment' : 'inline',
        filename: "image.#{format}",
        content_type: ALLOWED_FORMATS[format]
      }
    end

    def send_raster_file(raster_file, raster_opts, modification_time)
      expires_in 365.days, public: true
      response['Content-Length'] = File.size(raster_file.path).to_s
      response['Last-Modified'] = modification_time.httpdate
      response['ETag'] = format('"%x"', modification_time)
      # We can't use send_file on a temporary file that's deleted when we're
      # done with it, since send_file passes along file serving to the
      # webserver, so when the cache is turned off we'll use send_data.
      if TRICLOPS[:raster_cache][:enabled]
        send_file(raster_file.path, raster_send_file_options(raster_opts[:download], raster_opts[:format]))
      else
        send_data(IO.read(raster_file.path), raster_send_file_options(raster_opts[:download], raster_opts[:format]))
      end
    end
end
