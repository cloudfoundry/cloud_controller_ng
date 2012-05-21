# Copyright (c) 2009-2012 VMware, Inc.

require "cloud_controller/rest_controller/controller_dsl"
require "cloud_controller/rest_controller/messages"
require "cloud_controller/rest_controller/object_serialization"
require "cloud_controller/rest_controller/query_string_parser"
require "cloud_controller/rest_controller/paginator"
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

  def self.controller_from_name(name)
    VCAP::CloudController.const_get(name.to_s.singularize.camelize)
  end

  def self.controller_from_model(model)
    controller_from_model_name(model.class.name)
  end

  def self.controller_from_model_name(model_name)
    controller_from_name(model_name.split("::").last)
  end
end
