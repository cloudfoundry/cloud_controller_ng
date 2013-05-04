#!/usr/bin/env ruby

$:.unshift(File.expand_path("../../../lib", __FILE__))

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../../Gemfile", __FILE__)

require "rubygems"
require "bundler/setup"
require "cloud_controller"
require "irb/completion"

VCAP::CloudController::Runner.new(ARGV).send(:start_cloud_controller)
