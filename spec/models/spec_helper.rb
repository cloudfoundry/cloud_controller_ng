# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

Dir[File.expand_path("../helpers/*", __FILE__)].each do |file|
  require file
end

RSpec.configure do |rspec_config|
  rspec_config.include VCAP::CloudController::ModelSpecHelper
end
