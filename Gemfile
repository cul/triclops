source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Parameter validation
gem 'dry-schema', '~> 1.4'
# Use imogen for generating images
gem 'imogen', '0.2.0'
# gem 'imogen', path: '../imogen'
# gem 'imogen', git: 'https://github.com/cul/imogen.git', branch: 'libvips'

# Explicitly including io-wait dependency to match default version of the gem that comes with Ruby 3.0.
gem 'io-wait', '0.2.0'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.7'
# Use Puma as the app server
gem 'puma', '~> 3.11'
# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 7.0.2'
# Rainbow for text coloring
gem 'rainbow', '~> 3.0'
# Use SCSS for stylesheets
gem 'sass-rails', '~> 5'
# Use sqlite3 as the database for Active Record
gem 'sqlite3', '~> 1.4'
# Transpile app-like JavaScript. Read more: https://github.com/rails/webpacker
gem 'webpacker', '~> 4.0'
# Redis key-value store
gem 'redis', '~> 4.1'
gem 'redlock', '~> 1.0'

# Use Active Model has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Active Storage variant
# gem 'image_processing', '~> 1.2'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.4.2', require: false

group :development, :test do
  # rubocop + CUL presets
  gem 'rubocul', '~> 4.0.3'
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  # for json structure comparison in tests
  gem 'json_spec'
  # for factories
  gem 'factory_bot_rails', '~> 5.1'
  # rspec for testing
  gem 'rspec', '>= 3.11'
  gem 'rspec-rails', '~> 5.1'
  # simplecov for test coverage
  gem 'simplecov', '~> 0.17'
end

group :development do
  gem 'listen', '~> 3.3'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'web-console', '>= 3.3.0'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]
