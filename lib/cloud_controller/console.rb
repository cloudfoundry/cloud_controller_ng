#!/usr/bin/env ruby

$:.unshift(File.expand_path("../../../lib", __FILE__))

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../../Gemfile", __FILE__)

require "rubygems"
require "bundler/setup"
require "cloud_controller"
require "irb/completion"
require "pry"

@config_file = ARGV[0] || File.expand_path("../../../config/cloud_controller.yml", __FILE__)
unless File.exists?(@config_file)
  warn "#{@config_file} not found. Try running bin/console <PATH_TO_CONFIG_FILE>."
  exit 1
end
@config = VCAP::CloudController::Config.from_file(@config_file)
logger = Logger.new(STDOUT)

db_config = @config.fetch(:db).merge(log_level: :debug)

VCAP::CloudController::DB.connect(logger, db_config)
VCAP::CloudController::DB.load_models

if ENV["RACK_ENV"] == "development"
  $:.unshift(File.expand_path("../../../spec/support", __FILE__))
  require "machinist/sequel"
  require "machinist/object"
  require "fakes/blueprints"
end

module VCAP::CloudController
  binding.pry :quiet => true
end
