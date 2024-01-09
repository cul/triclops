# frozen_string_literal: true

require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Triclops
  class Application < Rails::Application
    include Cul::Omniauth::FileConfigurable

    config.load_defaults 7.0

    # Rails will use the Eastern time zone
    config.time_zone = 'Eastern Time (US & Canada)'
    # Database will store dates in UTC (which is the rails default behavior)
    config.active_record.default_timezone = :utc

    config.eager_load_paths << Rails.root.join('lib')

    config.active_job.queue_adapter = :resque
    config.active_job.queue_name_prefix = "triclops.#{Rails.env}"
    config.active_job.queue_name_delimiter = '.'
  end
end
