# frozen_string_literal: true

module Triclops::Iiif::Constants
  ALLOWED_FORMATS = {
    # 'png' => 'image/png', # For now, do not allow PNG (because it is generally bigger than jpg)
    'jpg' => 'image/jpeg'
  }.freeze
  DEFAULT_FORMAT = 'jpg'
  BASE_IMAGE_FORMAT = 'png'
  ALLOWED_QUALITIES = ['default', 'color', 'gray', 'bitonal'].freeze
  BASE_QUALITY = 'color'
  ALLOWED_ROTATIONS = [0, 90, 180, 270].freeze
  REDUCED_BASE_SIZE = 768
  RECOMMENDED_SIZES = [256, REDUCED_BASE_SIZE, 1280].freeze
  PRE_GENERATED_SQUARE_SIZES = [256].freeze
  TILE_SIZE = 512
  # TODO: Replace 'featured' with 'square' because that's preferred in IIIF 3.0.
  ALLOWED_REGIONS_REGEX = /full|square|\d+,\d+,\d+,\d+|pct:\d+,\d+,\d+,\d+/
  ALLOWED_SIZES_REGEX = /full|max|\d+,|,\d+|pct:\d+|\d+,\d+|!\d+,\d+/

  module CacheMissMode
    GENERATE_AND_DO_NOT_CACHE = 'generate_and_do_not_cache'
    GENERATE_AND_CACHE = 'generate_and_cache'
    ERROR = 'error'
    VALID_MODES = [ERROR, GENERATE_AND_CACHE, GENERATE_AND_DO_NOT_CACHE].freeze
  end
end
