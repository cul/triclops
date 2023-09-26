# Store version in a constant so that we can refer to it from anywhere without having to
# read the VERSION file in real time.
APP_VERSION = File.read(Rails.root.join('VERSION'))

# Load Triclops config
TRICLOPS = Rails.application.config_for(:triclops).deep_symbolize_keys

# Raste Cache config validation

if TRICLOPS[:raster_cache].nil? || TRICLOPS[:raster_cache][:enabled].nil?
  raise 'Missing TRICLOPS[raster_cache][enabled] config'
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
if TRICLOPS[:tmp_directory].nil?
  TRICLOPS[:tmp_directory] = Dir.tmpdir
end
