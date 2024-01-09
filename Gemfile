source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Use best_type for media type detection
gem 'best_type', '~> 0.0.10'
# For schema validation
gem 'dry-validation', '~> 1.10.0'
# Use imogen for generating images
# gem 'imogen', '~> 0.4.0'
# gem 'imogen', path: '../imogen'
gem 'imogen', git: 'https://github.com/cul/imogen.git', branch: 'iiif_tile_generation_fixes'
# Explicitly including io-wait dependency to match default version of the gem that comes with Ruby 3.0.
gem 'io-wait', '0.2.0'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.7'
# Use mysql as a database option for Active Record
gem 'mysql2', '~> 0.5.5'
# Use Puma as the app server
gem 'puma', '~> 5.2'
# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 7.0.8'
# Rainbow for text coloring
gem 'rainbow', '~> 3.0'
# Use Redis adapter to run Action Cable in production
gem 'redis', '~> 4.8' # NOTE: Updating the redis gem to v5 breaks the current redis namespace setup
gem 'redis-namespace', '~> 1.11'
# Redlock for redis-based locks
gem 'redlock', '~> 1.0'
# Resque for queued jobs
gem 'resque', '~> 2.6'
# Use SCSS for stylesheets
gem 'sass-rails', '~> 5'
# Use sqlite3 as the database for Active Record
gem 'sqlite3', '~> 1.4'
gem 'vite_rails'
# Use devise and omniauth for authentication
gem 'cul_omniauth', '~> 0.8.0'
gem 'devise'

gem 'psych', '~> 3'

# Fetch ldap details - first name, last name, etc.
gem 'net-ldap'

# Use Active Model has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Active Storage variant
# gem 'image_processing', '~> 1.2'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.4.2', require: false

group :development, :test do
  # rubocop + CUL presets
  gem 'rubocul', '~> 4.0.8'
  # gem 'rubocul', path: '../rubocul'
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  # for json structure comparison in tests
  gem 'json_spec'
  # for factories
  gem 'factory_bot_rails', '~> 6.0'
  # rspec for testing
  gem 'rspec', '>= 3.11'
  gem 'rspec-rails', '~> 5.1'
  # simplecov for test coverage
  gem 'simplecov', '~> 0.22', require: false
end

group :development do
  gem 'capistrano', '~> 3.18.0', require: false
  gem 'capistrano-cul', require: false
  gem 'capistrano-passenger', '~> 0.1', require: false
  gem 'capistrano-rails', '~> 1.4', require: false

  gem 'listen', '~> 3.3'
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'web-console', '>= 3.3.0'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]
