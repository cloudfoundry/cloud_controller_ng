# Copyright (c) 2009-2012 VMware, Inc.

require 'sequel'
require 'vcap/logging'

module VCAP
  module CloudController; end
end

require 'cloud_controller/db'
require "sequel_plugins/vcap_validations"
require "sequel_plugins/vcap_serialization"
