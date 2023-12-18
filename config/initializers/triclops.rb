# Store version in a constant so that we can refer to it from anywhere without having to
# read the VERSION file in real time.
APP_VERSION = File.read(Rails.root.join('VERSION'))

# Load Triclops config
TRICLOPS = Rails.application.config_for(:triclops).deep_symbolize_keys

# Cache known placeholder images
PLACEHOLDER_ROOT = Rails.root.join('app/assets/images/placeholders')
placeholder_image_paths = Dir.glob(File.join(PLACEHOLDER_ROOT, '/*'))
KNOWN_PLACEHOLDER_IDENTIFIERS = placeholder_image_paths.map do |file_path|
  "placeholder:#{File.basename(file_path, '.*')}"
end
PLACEHOLDER_SIZE = Imogen.with_image(placeholder_image_paths.first, &:width)

def validate_triclops_config!
  if TRICLOPS[:raster_cache].nil? || TRICLOPS[:raster_cache][:on_miss].nil?
    raise 'Missing TRICLOPS[raster_cache][on_miss] config'
  elsif !Triclops::Iiif::Constants::CacheMissMode::VALID_MODES.include?(TRICLOPS[:raster_cache][:on_miss])
    raise 'Invalid value for TRICLOPS[raster_cache][on_miss] config.  '\
      "Must be one of: #{Triclops::Iiif::Constants::CacheMissMode::VALID_MODES.join(', ')}"
  end

  if TRICLOPS[:raster_cache] && TRICLOPS[:raster_cache][:enabled] && TRICLOPS[:raster_cache][:directory].nil?
    raise 'Missing TRICLOPS[raster_cache][directory] config (required when TRICLOPS[raster_cache][enabled] == true)'
  end

  # Lock config validation
  raise 'Missing TRICLOPS[:lock] config' if TRICLOPS[:lock].nil?

  [:lock_timeout, :retry_delay, :retry_count].each do |required_key|
    if TRICLOPS[:lock][required_key].nil?
      raise "Missing required config TRICLOPS[:config][:#{required_key}]"
    end
  end

  # If temp_directory is not set, default to ruby temp dir
  TRICLOPS[:tmp_directory] = Dir.tmpdir if TRICLOPS[:tmp_directory].nil?
end

# Raster cache config validation
Rails.application.config.after_initialize do
  # We need to run this after_initialize because at least one of our validations depends on
  # a constant from an auto-loaded file, and modules are only auto-loaded after initialization.
  validate_triclops_config!
end

Rails.application.config.active_job.queue_adapter = :inline if TRICLOPS['run_queued_jobs_inline']
