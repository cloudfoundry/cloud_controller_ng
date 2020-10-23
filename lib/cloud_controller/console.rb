#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.expand_path('../../lib', __dir__))

ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __dir__)

require 'rubygems'
require 'bundler/setup'
require 'cloud_controller'
require 'irb/completion'
require 'pry'
begin
  require File.expand_path('../../spec/support/bootstrap/db_config.rb', __dir__)
rescue LoadError
  # db_config.rb does not exist in a release, but a config with a database should exist there.
end

@config_file = ARGV[0] || ENV['CLOUD_CONTROLLER_NG_CONFIG'] || File.expand_path('../../config/cloud_controller.yml', __dir__)
unless File.exist?(@config_file)
  warn "#{@config_file} not found. Try running bin/console <PATH_TO_CONFIG_FILE>."
  exit 1
end

context = ARGV[1].try(:to_sym) || :api
config_kwargs = { context: context }
if ENV['CLOUD_CONTROLLER_NG_SECRETS']
  secrets_hash = VCAP::CloudController::SecretsFetcher.fetch_secrets_from_file(ENV['CLOUD_CONTROLLER_NG_SECRETS'])
  config_kwargs.merge!(secrets_hash: secrets_hash)
end

@config = VCAP::CloudController::Config.load_from_file(@config_file, config_kwargs)
logger = Logger.new($stdout)

db_config = @config.set(:db, @config.get(:db).merge(log_level: :debug))
if defined? DbConfig
  db_config[:database] ||= DbConfig.new.config[:database]
end

VCAP::CloudController::DB.load_models_without_migrations_check(db_config, logger)
@config.configure_components

if ENV['NEW_RELIC_ENV'] == 'development'
  $LOAD_PATH.unshift(File.expand_path('../../spec/support', __dir__))
  require 'machinist/sequel'
  require 'machinist/object'
  require 'fakes/blueprints'
end

module VCAP::CloudController
  # rubocop:disable Lint/Debugger
  binding.pry quiet: true
  # rubocop:enable Lint/Debugger
end
