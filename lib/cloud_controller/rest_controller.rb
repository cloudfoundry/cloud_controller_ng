require "cloud_controller/rest_controller/controller_dsl"
require "cloud_controller/rest_controller/messages"
require "cloud_controller/rest_controller/object_serialization"
require "cloud_controller/rest_controller/paginator"
require "cloud_controller/rest_controller/routes"
require "cloud_controller/rest_controller/base"
require "cloud_controller/rest_controller/model_controller"

module VCAP::CloudController
  def self.controller_from_model(model)
    controller_from_model_name(model.class.name)
  end

  def self.controller_from_model_name(model_name)
    controller_from_name(model_name.to_s.split("::").last)
  end

  private

  def self.controller_from_name(name)
    VCAP::CloudController.const_get("#{name.to_s.pluralize.camelize}Controller")
  end
end
