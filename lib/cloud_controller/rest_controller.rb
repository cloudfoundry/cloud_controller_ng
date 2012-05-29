# Copyright (c) 2009-2012 VMware, Inc.

require "cloud_controller/rest_controller/controller_dsl"
require "cloud_controller/rest_controller/messages"
require "cloud_controller/rest_controller/object_serialization"
require "cloud_controller/rest_controller/routes"
require "cloud_controller/rest_controller/base"

module VCAP::CloudController
  def self.rest_controller(name, &blk)
    klass = Class.new RestController::Base
    self.const_set name, klass
    klass.class_eval &blk
    klass.class_eval do
      define_messages
      define_routes
    end
  end
end
