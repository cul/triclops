class Iiif::ImagesController < ApplicationController
  include ActionController::Live
  include Triclops::Iiif::ImagesController::Schemas
  include Triclops::Iiif::ImagesController::Sizing

  before_action :add_cors_header!, only: [:info]
  before_action :set_resource_or_handle_not_found, only: [:info, :raster, :test_viewer]

  def info
    unless @resource.ready?
      redirect_to params.to_unsafe_h.merge(identifier: @resource.placeholder_identifier_for_pcdm_type), status: :found
      return
    end

    render json: @resource.iiif_info(
      iiif_info_url(@resource.identifier)[0...-10], # chop off last 10 characters to remove "/info.json"
      @resource.width,
      @resource.height,
      Triclops::Iiif::Constants::RECOMMENDED_SIZES.map { |size| closest_size(size, @resource.width, @resource.height) },
      Triclops::Iiif::Constants::ALLOWED_FORMATS.keys,
      Triclops::Iiif::Constants::ALLOWED_QUALITIES,
      Triclops::Iiif::Constants::TILE_SIZE,
      @resource.scale_factors_for_tile_size(Triclops::Iiif::Constants::TILE_SIZE)
    )
  end

  # GET /iiif/2/:identifier/:region/:size/:rotation/:quality.(:format)
  # e.g. /iiif/2/sample/full/full/0/default.png
  def raster
    params_as_regular_hash = params.to_unsafe_h
    params_validation_result = Triclops::Contracts::Iiif2ImageParamsContract.new.call(params_as_regular_hash)

    if params_validation_result.errors.present?
      render json: contract_validation_error_response(params_validation_result), status: :bad_request
      return
    end

    original_raster_opts = params_validation_result.to_h
    original_raster_opts.delete(:identifier) # :identifier isn't part of our "raster opts"
    normalized_raster_opts = Triclops::Iiif::RasterOptNormalizer.normalize_raster_opts(@resource, original_raster_opts)

    # Whenever a valid resource is requested, cache the Resource identifier in
    # our ResourceAccessStatCache. This cache will be periodically flushed to the
    # Resource database (by a separate process) so that many access time updates
    # are done in batch (and do not slow down individual Raster requests).
    # We're keeping track of access time so that when our Raster cache gets full
    # and we want to clear out old cached Raster images, we know which frequently
    # accessed cache items should be kept.
    # Note: We only need to cache access times if caching is enabled. Resource
    # access time doesn't matter if we're not caching anything.
    Triclops::ResourceAccessStatCache.instance.add(@resource.identifier) if TRICLOPS[:raster_cache][:enabled]

    if @resource.ready?
      # cache_enabled = cacheable_raster?(@resource, normalized_raster_opts)
      cache_hit = @resource.raster_exists?(normalized_raster_opts)
      unless cache_hit
        Rails.logger.error(
          "[#{@resource.identifier}] "\
          "Cache MISS: (original_raster_opts: #{original_raster_opts}) "\
          "(normalized_raster_opts: #{normalized_raster_opts.inspect})"
        )
      end
      if cache_hit || TRICLOPS[:raster_cache][:on_miss] == 'generate_and_cache' || @resource.source_uri_is_placeholder?
        @resource.yield_cached_raster(normalized_raster_opts) do |raster_file|
          send_raster_file(raster_file, normalized_raster_opts, @resource.updated_at, delivery_method: :send_file)
        end
      elsif TRICLOPS[:raster_cache][:on_miss] == 'generate_and_do_not_cache'
        @resource.yield_uncached_raster(normalized_raster_opts) do |raster_file|
          send_raster_file(raster_file, normalized_raster_opts, @resource.updated_at, delivery_method: :send_data)
        end
      else # TRICLOPS[:raster_cache][:on_miss] == 'error'
        render plain: 'not found', status: :not_found
      end
    else
      Rails.logger.debug(
        "[#{@resource.identifier}] Redirecting raster request to placeholder image because resource is not ready"
      )
      redirect_to params.to_unsafe_h.merge(identifier: @resource.placeholder_identifier_for_pcdm_type), status: :found
    end
  end

  def test_viewer
    render layout: 'iiif_viewer'
  end

  private

  # def raster_params
  #   params.permit(:version, :identifier, :region, :size, :rotation, :quality, :format, :download)
  # end

  def error_response(errors)
    { result: false, errors: errors }
  end

  def contract_validation_error_response(contract_validation_result)
    error_messages = contract_validation_result.errors.map { |e| "#{e.path.join(' => ')} #{e.text}" }
    error_response(error_messages)
  end

  def set_resource_or_handle_not_found
    identifier = params[:identifier]

    # Set @resource and return (if resource found)
    return if (
      @resource = Resource.find_by(identifier: identifier)
    )

    # Instantiate placeholder @resource and return (if identifier is a valid placeholder identifier)
    return if KNOWN_PLACEHOLDER_IDENTIFIERS.include?(identifier) && (
      @resource = Resource.placeholder_resource_for(identifier)
    )

    # If the resource cannot be found, redirect to a generic file placeholder url
    Rails.logger.debug("Redirecting to placeholder:unavailable because identifier #{identifier} is unknown.")
    redirect_to params.to_unsafe_h.merge(identifier: 'placeholder:unavailable'), status: :found
  end

  def raster_send_file_options(download, format)
    filename = "image.#{format}"
    {
      disposition: download ? 'attachment' : 'inline',
      filename: filename,
      content_type: ::BestType.mime_type.for_file_name(filename)
    }
  end

  # @param delivery_method - Either :send_file or :send_data.  Choose send_file for a persistent
  #                          file on the filesystem, or send_data for a temporary file.
  def send_raster_file(raster_file, raster_opts, modification_time, delivery_method: :send_file)
    expires_in 365.days, public: true
    response['Content-Length'] = File.size(raster_file.path).to_s
    response['Last-Modified'] = modification_time.httpdate
    response['ETag'] = format('"%x"', modification_time)
    # We can't use send_file on a temporary file that's deleted when we're
    # done with it, since send_file delegates file serving to the
    # webserver, so when the cache is turned off we'll use send_data.
    if delivery_method == :send_file
      send_file(raster_file.path, raster_send_file_options(raster_opts[:download], raster_opts[:format]))
    elsif delivery_method == :send_data
      send_data(IO.read(raster_file.path), raster_send_file_options(raster_opts[:download], raster_opts[:format]))
    else
      raise 'Invalid delivery method.'
    end
  end

  # def cacheable_raster?(resource, raster_opts)
  #   # Do not use cache if the cache is disabled globally
  #   return false unless TRICLOPS[:raster_cache][:enabled]

  #   # Serve cached images for placeholder resources
  #   return true if resource.source_uri_is_placeholder?

  #   # Serve a cached raster if the raster already exists in the cache
  #   return true if resource.raster_exists?(raster_opts)

  #   # Otherwise do not serve from the cache
  #   false
  # end
end
