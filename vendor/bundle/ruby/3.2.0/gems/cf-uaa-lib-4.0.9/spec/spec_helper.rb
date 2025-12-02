#--
# Cloud Foundry
# Copyright (c) [2009-2014] Pivotal Software, Inc. All Rights Reserved.
#
# This product is licensed to you under the Apache License, Version 2.0 (the "License").
# You may not use this product except in compliance with the License.
#
# This product includes a number of subcomponents with
# separate copyright notices and license terms. Your use of these
# subcomponents is subject to the terms and conditions of the
# subcomponent's license, as noted in the LICENSE file.
#++

if ENV['COVERAGE']
  require "simplecov"
  if ENV['COVERAGE'] =~ /rcov/
    require "simplecov-rcov"
    SimpleCov.formatter = SimpleCov::Formatter::RcovFormatter
  end
  SimpleCov.add_filter "^#{File.dirname(__FILE__)}" if ENV['COVERAGE'] =~ /exclude-spec/
  SimpleCov.add_filter "^#{File.expand_path(File.join(File.dirname(__FILE__), "..", "vendor"))}" if ENV['COVERAGE'] =~ /exclude-vendor/
  SimpleCov.start
end

require 'rspec'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.syntax = [:expect, :should]
  end
end
