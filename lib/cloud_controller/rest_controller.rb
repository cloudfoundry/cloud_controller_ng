require 'controllers/base/base_controller'
require 'controllers/base/model_controller'
require 'cloud_controller/rest_controller/controller_dsl'
require 'cloud_controller/rest_controller/secure_eager_loader'
require 'cloud_controller/rest_controller/preloaded_object_serializer'
require 'cloud_controller/rest_controller/object_renderer'
require 'cloud_controller/rest_controller/paginated_collection_renderer'

module VCAP::CloudController
  def self.controller_from_model(model)
    controller_from_model_name(model.class.name)
  end

  def self.controller_from_model_name(model_name)
    controller_from_name(model_name.to_s.split('::').last)
  end

  private

  def self.controller_from_name(name)
    VCAP::CloudController.const_get("#{name.to_s.pluralize.camelize}Controller")
  end
end
