class Resource < ApplicationRecord
  include Triclops::Resource::IiifInfo
  include Triclops::Resource::AsJson
  include Triclops::Resource::Validations

  before_save :run_image_property_extraction!

  def clear_image_dimensions_if_location_uri_changed!
    if location_uri_changed?
      # If the location_uri changed, we need to re-scan the associated file to detect the new image
      # file's width and height, so we'll clear those fields here so they'll be re-extracted.
      self.width = nil
      self.height = nil
    end
  end

  def missing_image_info?
    self.width.blank? || self.height.blank? || self.featured_region.blank?
  end

  def run_image_property_extraction!
    return unless missing_image_info? || location_uri_changed?

    self.with_source_image_file do |source_image_file|
      Imogen.with_image(source_image_file.path) do |img|
        self.width = img.width
        self.height = img.height

        # If the feature region is currently blank, then we definitely need to extract a featured
        # region -- but also, if the width changed or the height changed, any old featured region
        # is no longer valid and we need to extract a new one.
        extract_autodetected_region_from_image(img) if self.featured_region.blank? || width_changed? || height_changed?
      end
    end
  end

  # Yields a block with a File reference to the specified raster.
  # @param raster_opts [Hash]
  #   A hash of IIIF options (e.g. {region: '...', size: '...', etc. }).
  # @param cache_enabled [boolean]
  #   If true, serves a cached version of the raster (when available) or
  #   generates and caches a new raster.  If false, always generates a new
  #   raster and does not cache that new raster.
  #
  # @yield raster_file [File] A file reference to the specified raster.
  # @return [void]
  def raster(raster_opts, cache_enabled)
    processed_raster_opts = preprocess_raster_opts(raster_opts)

    if cache_enabled
      yield_cached_raster(processed_raster_opts) { |raster_file| yield raster_file }
    else
      yield_uncached_raster(processed_raster_opts) { |raster_file| yield raster_file }
    end
  end

  # Pre-processes raster opts before they're used later in the conversion chain.
  # Performs operations like converting 'featured' region into a specific crop
  # region and aliasing 'color' quality as 'default' quality.
  #
  # @api private
  # @param raster_opts [Hash]
  #   A hash of IIIF options (e.g. {identifier: '...', region: '...', size: '...', etc. }).
  # @return [Hash] the processed version of raster_opts
  def preprocess_raster_opts(raster_opts)
    # duplicate processed_raster_opts so we don't modify the incoming argument
    processed_raster_opts = raster_opts.dup

    # {region: 'featured'} should be converted into {region: 'x,y,w,h'}
    processed_raster_opts[:region] = self.featured_region if processed_raster_opts[:region] == 'featured'

    # {quality: 'default'} is an alias for {quality: 'color'}
    processed_raster_opts[:quality] = 'color' if processed_raster_opts[:quality] == 'default'

    processed_raster_opts
  end

  # @api private
  def cache_path(raster_opts)
    Triclops::RasterCache.instance.cache_path(
      location_uri_is_placeholder? ? self.location_uri : self.identifier,
      raster_opts
    )
  end

  # @api private
  def yield_cached_raster(raster_opts)
    # Get cache path
    raster_file_path = cache_path(raster_opts)

    unless File.exist?(raster_file_path)
      # We use a blocking lock so that two processes don't try to to run the
      # same file creation operation at the same time.
      Triclops::Lock.instance.with_blocking_lock(raster_file_path) do
        # We do a second File.exists? check inside of the lock to ensure
        # that file generation does not occur if the file was created
        # while waiting to establish this lock.
        unless File.exist?(raster_file_path)
          FileUtils.mkdir_p(File.dirname(raster_file_path))
          self.with_source_image_file do |source_image_file|
            Triclops::Raster.generate(source_image_file.path, raster_file_path, raster_opts)
          end
        end
      end
    end

    yield File.new(raster_file_path)
  end

  # @api private
  def yield_uncached_raster(raster_opts)
    temp_file = nil
    raster_tempfile_path = self.class.generate_raster_tempfile_path(raster_opts[:format])
    FileUtils.mkdir_p(File.dirname(raster_tempfile_path))
    self.with_source_image_file do |source_image_file|
      Triclops::Raster.generate(source_image_file.path, raster_tempfile_path, raster_opts)
    end
    temp_file = File.new(raster_tempfile_path)
    yield temp_file
  ensure
    # Close file if it's open and then unlink the file.
    if temp_file
      temp_file.close unless temp_file.closed?
      File.unlink(temp_file)
    end
  end

  # Yields a block with a File reference to the source image file for this Resource.
  #
  # @api private
  # @yield source_image_file [File] A file holding the source image content.
  def with_source_image_file
    raise Errno::ENOENT, 'Missing location_uri' if self.location_uri.blank?
    protocol, path = self.location_uri.split('://')

    case protocol
    when 'railsroot'
      yield File.new(Rails.root.join(path).to_s)
      return
    when 'placeholder'
      yield File.new(Rails.root.join('app', 'assets', 'images', 'placeholders', path + '.png').to_s)
      return
    when 'file'
      if File.exist?(path)
        yield File.new(path)
        return
      end
    end
    raise Errno::ENOENT, "Could not resolve file location: #{self.location_uri}"
  end

  # @api private
  def location_uri_is_readable?
    with_source_image_file do |file|
      return File.readable?(file)
    end
  rescue Errno::ENOENT
    false
  end

  # Returns true if this Resource's location_uri points to a placeholder image value.
  #
  # @api private
  # @return [Boolean] true if location_uri starts with 'placeholder://'
  def location_uri_is_placeholder?
    return false if self.location_uri.nil?
    self.location_uri.start_with?('placeholder://')
  end

  def self.generate_raster_tempfile_path(extension = '.blob')
    loop do
      # Generate unique temp raster in temp location
      raster_tempfile_path = File.join(TRICLOPS[:tmp_directory], "#{Rails.application.class.module_parent_name.underscore}-tmp-#{SecureRandom.uuid}.#{extension}")
      return raster_tempfile_path unless File.exist?(raster_tempfile_path)
    end
  end

  # @api private
  def extract_autodetected_region_from_image(img)
    # We try to use at least 768 pixels from any image when generating a
    # featured area crop so that we don't unintentionally get a tiny
    # 10px x 10px crop that gets scaled up for users and looks blocky/blurry.
    left_x, top_y, right_x, bottom_y = Imogen::Iiif::Region::Featured.get(img, 768)
    x = left_x
    y = top_y
    w = right_x - left_x
    h = bottom_y - top_y
    self.featured_region = "#{x},#{y},#{w},#{h}"
  end
end
