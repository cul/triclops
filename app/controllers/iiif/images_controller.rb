class Iiif::ImagesController < ApplicationController
  include ActionController::Live
  include Triclops::Iiif::ImagesController::Schemas
  include Triclops::Iiif::ImagesController::Sizing

  # skip_before_action :verify_authenticity_token, only: [:raster_preflight_check]
  before_action :add_cors_header!, only: [
    :info,
    :raster
    # :raster_preflight_check
  ]
  before_action :set_resource_or_handle_not_found, only: [:info, :raster, :test_viewer]
  before_action :set_base_type, only: [:info, :raster]
  before_action :require_token_if_resource_has_view_limitation!, only: [:raster] # For now, not limiting info endpoint

  # def raster_preflight_check
  #   render plain: 'Success', status: :ok
  # end

  def info
    unless @resource.ready?
      redirect_to params.to_unsafe_h.merge(identifier: @resource.placeholder_identifier_for_pcdm_type), status: :found
      return
    end

    assign_compliance_level_header!(response)

    render json: info_json_for_resource(@resource, @base_type)
  end

  # GET /iiif/2/:base_type/:identifier/:region/:size/:rotation/:quality.(:format)
  # e.g. /iiif/2/standard/cul:123/full/full/0/default.png
  def raster
    params_as_regular_hash = params.to_unsafe_h
    params_validation_result = Triclops::Contracts::Iiif2ImageParamsContract.new.call(params_as_regular_hash)
    if params_validation_result.errors.present?
      render json: contract_validation_error_response(params_validation_result), status: :bad_request
      return
    end

    original_raster_opts = params_validation_result.to_h
    original_raster_opts.delete(:identifier) # :identifier isn't part of our "raster opts"
    base_type = params[:base_type] # :base_type isn't part of our "raster opts"

    handle_ready_resource_or_redirect(@resource, base_type, original_raster_opts)
  end

  def test_viewer
    render layout: 'test_viewer'
  end

  private

  def require_token_if_resource_has_view_limitation!
    return if TRICLOPS[:skip_tokens]
    # Placeholder images don't ever require a token
    return if @resource.identifier.start_with?('placeholder')

    # Featured and limited images don't ever require a token
    return if [Triclops::Iiif::Constants::BASE_TYPE_FEATURED, Triclops::Iiif::Constants::BASE_TYPE_LIMITED].include?(@base_type)

    # If this resource does not have a view limitation, no token is required
    return unless @resource.has_view_limitation

    # This will immediately render a 401 if no token was provided
    authenticate_or_request_with_http_token do |token, _options|
      validate_image_request_token(token, @base_type, @resource.identifier, request.remote_ip)
    end
  end

  def validate_image_request_token(token, base_type, resource_identifier, client_ip)
    Triclops::Utils::TokenUtils.token_is_valid?(token, base_type, resource_identifier, client_ip)
  end

  def handle_ready_resource_or_redirect(resource, base_type, original_raster_opts)
    # Whenever a valid resource is requested, cache the Resource identifier in
    # our ResourceAccessStatCache. This cache will be periodically flushed to the
    # Resource database (by a separate process) so that many access time updates
    # are done in batch (and do not slow down individual Raster requests).
    # We're keeping track of access time so that when our Raster cache gets full
    # and we want to clear out old cached Raster images, we know which frequently
    # accessed cache items should be kept.
    # Note: We only need to cache access times if caching is enabled. Resource
    # access time doesn't matter if we're not caching anything.
    Triclops::ResourceAccessStatCache.instance.add(resource.identifier) if
      TRICLOPS[:raster_cache][:access_stats_enabled]

    if resource.ready?
      normalized_raster_opts = Triclops::Iiif::RasterOptNormalizer.normalize_raster_opts(resource, original_raster_opts)
      handle_ready_resource(base_type, original_raster_opts, normalized_raster_opts)
    else
      Rails.logger.debug(
        "[#{resource.identifier}] Redirecting raster request to placeholder image because resource is not ready"
      )
      redirect_to params.to_unsafe_h.merge(identifier: resource.placeholder_identifier_for_pcdm_type), status: :found
    end
  end

  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def handle_ready_resource(base_type, original_raster_opts, normalized_raster_opts)
    cache_hit = @resource.raster_exists?(base_type, normalized_raster_opts)
    unless cache_hit
      Rails.logger.error(
        "[#{@resource.identifier}] "\
        "Cache MISS: (original_raster_opts: #{original_raster_opts}) "\
        "(normalized_raster_opts: #{normalized_raster_opts.inspect})"
      )
    end
    if cache_hit || TRICLOPS[:raster_cache][:on_miss] == Triclops::Iiif::Constants::CacheMissMode::GENERATE_AND_CACHE || @resource.source_uri_is_placeholder?
      @resource.yield_cached_raster(base_type, normalized_raster_opts) do |raster_file|
        send_raster_file(raster_file, normalized_raster_opts, @resource.updated_at, delivery_method: :send_file)
      end
    elsif TRICLOPS[:raster_cache][:on_miss] == Triclops::Iiif::Constants::CacheMissMode::GENERATE_AND_DO_NOT_CACHE
      @resource.yield_uncached_raster(base_type, normalized_raster_opts) do |raster_file|
        send_raster_file(raster_file, normalized_raster_opts, @resource.updated_at, delivery_method: :send_data)
      end
    else # TRICLOPS[:raster_cache][:on_miss] == Triclops::Iiif::Constants::CacheMissMode::ERROR

      # !!! THIS IS TEMPORARY.  AFTER RASTER CACHE RESTRUCTURING IS COMPLETE, REPLACE THE CODE BELOW. !!!
      # If a raster is not found at the normalized opt location,
      normalized_raster_opts_with_original_size_opt = normalized_raster_opts.merge(size: original_raster_opts[:size])
      if normalized_raster_opts != normalized_raster_opts_with_original_size_opt
        handle_ready_resource(base_type, original_raster_opts, normalized_raster_opts_with_original_size_opt)
      else
        render plain: 'not found', status: :not_found
      end

    end
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

  def error_response(errors)
    { result: false, errors: errors }
  end

  def contract_validation_error_response(contract_validation_result)
    error_messages = contract_validation_result.errors.map { |e| "#{e.path.join(' => ')} #{e.text}" }
    error_response(error_messages)
  end

  def set_base_type
    @base_type = params[:base_type]
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
    assign_headers_for_sent_file!(response, raster_file, modification_time)
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

  def assign_headers_for_sent_file!(resp, raster_file, modification_time)
    resp['Content-Length'] = File.size(raster_file.path).to_s
    resp['Last-Modified'] = modification_time.httpdate
    resp['ETag'] = format('"%x"', modification_time)
  end

  def compliance_level_url
    if TRICLOPS[:raster_cache][:on_miss] == Triclops::Iiif::Constants::CacheMissMode::ERROR
      'http://iiif.io/api/image/2/level0.json'
    else
      'http://iiif.io/api/image/2/level1.json'
    end
  end

  def assign_compliance_level_header!(resp)
    resp.set_header('Link', compliance_level_url)
  end

  def info_json_for_resource(resource, base_type)
    width, height = dimensions_for_base_type(resource, base_type)
    resource.iiif_info(
      iiif_info_url(base_type, resource.identifier)[0...-10], # chop off last 10 characters to remove "/info.json"
      width,
      height,
      Triclops::Iiif::Constants::RECOMMENDED_SIZES.map { |size| closest_size(size, width, height) },
      Triclops::Iiif::Constants::ALLOWED_FORMATS.keys,
      Triclops::Iiif::Constants::ALLOWED_QUALITIES,
      Triclops::Iiif::Constants::TILE_SIZE,
      Imogen::Iiif::Tiles.scale_factors_for(width, height, Triclops::Iiif::Constants::TILE_SIZE),
      compliance_level_url
    )
  end

  def dimensions_for_base_type(resource, base_type)
    raise Triclops::Exceptions::UnknownBaseType, "Unknown base type: #{base_type}" unless Triclops::Iiif::Constants::ALLOWED_BASE_TYPES.include?(base_type)

    case base_type
    when 'standard'
      [resource.standard_width, resource.standard_height]
    when 'limited'
      [resource.limited_width, resource.limited_height]
    when 'featured'
      [resource.featured_width, resource.featured_height]
    end
  end
end
