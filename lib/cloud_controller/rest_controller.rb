# Copyright (c) 2009-2012 VMware, Inc.

require "cloud_controller/rest_controller/controller_dsl"
require "cloud_controller/rest_controller/messages"
require "cloud_controller/rest_controller/object_serialization"
require "cloud_controller/rest_controller/paginator"
require "cloud_controller/rest_controller/routes"
require "cloud_controller/rest_controller/base"
require "cloud_controller/rest_controller/model_controller"

module VCAP::CloudController
  def self.rest_controller(name, &blk)
    klass = Class.new RestController::ModelController
    self.const_set name, klass
    klass.class_eval &blk
    if klass.default_routes?
      klass.class_eval do
        define_messages
        define_routes
      end
    end
  end

  def self.controller_from_name(name)
    VCAP::CloudController.const_get(name.to_s.singularize.camelize)
  end

  def self.controller_from_model(model)
    controller_from_model_name(model.class.name)
  end

  def self.controller_from_model_name(model_name)
    controller_from_name(model_name.to_s.split("::").last)
  end
end
