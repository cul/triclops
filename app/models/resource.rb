class Resource < ApplicationRecord
  include Triclops::Resource::Info

  validates :identifier, :location_uri, presence: true
  validates :width, :height, presence: true, unless: -> { location_uri_is_placeholder? }

  # Yields a block with a File reference to the specified raster.
  # @param raster_opts [Hash]
  #   A hash of IIIF options (e.g. {identifer: '...', region: '...', size: '...', etc. }).
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

  # Note: In the future, this method is unlikely to be called by Triclops because
  # Hyacinth or Derivativo will be sending or updating crop region data.
  def extract_featured_region!
    self.with_source_image_file do |source_image_file|
      Imogen.with_image(source_image_file.path) do |img|
        # We try to use at least 768 pixels from any image when generating a
        # featured area crop so that we don't unintentionally get a tiny
        # 10px x 10px crop that gets scaled up for users and looks blocky/blurry.
        left_x, top_y, right_x, bottom_y = Imogen::Iiif::Region::Featured.get(img, 768)
        x = left_x
        y = top_y
        w = right_x - left_x
        h = bottom_y - top_y
        self.update(featured_region: "#{x},#{y},#{w},#{h}")
      end
    end
  end

  # Pre-processes raster opts before they're used later in the conversion chain.
  # Performs operations like converting 'featured' region into a specific crop
  # region and aliasing 'color' quality as 'default' quality.
  # @param raster_opts [Hash]
  #   A hash of IIIF options (e.g. {identifer: '...', region: '...', size: '...', etc. }).
  # @return [Hash] the processed version of raster_opts
  def preprocess_raster_opts(raster_opts)
    # duplicate processed_raster_opts so we don't modify the incoming argument
    processed_raster_opts = raster_opts.dup

    # {region: 'featured'} should be converted into {region: 'x,y,w,h'}
    if processed_raster_opts[:region] == 'featured'
      extract_featured_region! if self.featured_region.blank?
      processed_raster_opts[:region] = self.featured_region
    end

    # {quality: 'default'} is an alias for {quality: 'color'}
    processed_raster_opts[:quality] = 'color' if processed_raster_opts[:quality] == 'default'

    processed_raster_opts
  end

  def cache_path(raster_opts)
    return Triclops::RasterCache.instance.cache_path(raster_opts.merge(identifier: self.location_uri)) if location_uri_is_placeholder?
    Triclops::RasterCache.instance.cache_path(raster_opts)
  end

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
  # @yield source_image_file [File] A file holding the source image content.
  def with_source_image_file
    protocol, path = self.location_uri.split('://')

    case protocol
    when 'railsroot'
      yield File.new(Rails.root.join(path).to_s)
    when 'placeholder'
      yield File.new(Rails.root.join('app', 'assets', 'images', 'placeholders', path + '.png').to_s)
    when 'file'
      yield File.new(path)
    else
      raise Errno::ENOENT, "File not found at <#{self.location_uri}>"
    end
  end

  # Returns true if this Resource's location_uri points to a placeholder image value.
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
end
