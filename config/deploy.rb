# frozen_string_literal: true

# config valid for current version and patch releases of Capistrano
lock '~> 3.17.0'

set :instance, 'ren'
set :application, 'triclops'
set :deploy_name, "#{fetch(:application)}_#{fetch(:stage)}"

set :rails_env, fetch(:deploy_name)
set :rvm_ruby_version, fetch(:deploy_name)

set :repo_url, 'git@github.com:cul/ren-triclops.git'

set :remote_user, "#{fetch(:instance)}serv"

# Default branch is :main
# ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

# Default deploy_to directory is /var/www/my_app_name
set :deploy_to,   "/opt/passenger/#{fetch(:instance)}/#{fetch(:deploy_name)}"

# Default value for :format is :airbrussh.
# set :format, :airbrussh

# You can configure the Airbrussh format using :format_options.
# These are the defaults.
# set :format_options, command_output: true, log_file: "log/capistrano.log", color: :auto, truncate: :auto

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
append  :linked_files,
        'config/database.yml',
        'config/triclops.yml',
        'config/master.key',
        'config/redis.yml'

# Default value for linked_dirs is []
append :linked_dirs, 'log', 'tmp/pids', 'node_modules', 'public/packs'

set :passenger_restart_with_touch, true

# Default value for default_env is {}
set :default_env, { NODE_ENV: 'production' }

# Default value for local_user is ENV['USER']
# set :local_user, -> { `git config user.name`.chomp }

# Default value for keep_releases is 5
set :keep_releases, 3

# Uncomment the following to require manually verifying the host key before first deploy.
# set :ssh_options, verify_host_key: :secure