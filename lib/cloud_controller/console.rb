#!/usr/bin/env ruby

$:.unshift(File.expand_path("../../../lib", __FILE__))

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../../Gemfile", __FILE__)

require "rubygems"
require "bundler/setup"
require "cloud_controller"
require "irb/completion"
require "pry"

@config_file = File.expand_path("../../../config/cloud_controller.yml", __FILE__)
@config = VCAP::CloudController::Config.from_file(@config_file)
logger = Logger.new(STDOUT)

db_config = @config.fetch(:db).merge(log_level: :debug)

VCAP::CloudController::DB.connect(logger, db_config)

module VCAP::CloudController
  binding.pry :quiet => true
end
