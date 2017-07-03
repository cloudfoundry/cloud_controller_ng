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

  def self.controller_from_name(name)
    controller_from_name_mapping.fetch(name) do
      VCAP::CloudController.const_get("#{name.to_s.pluralize.camelize}Controller")
    end
  end

  def self.controller_from_relationship(relationship)
    return nil unless relationship.try(:association_controller).present?
    VCAP::CloudController.const_get(relationship.association_controller)
  end

  def self.controller_from_name_mapping
    @controller_from_name ||= {}
  end

  def self.set_controller_for_model_name(model_name:, controller:)
    controller_from_name_mapping[model_name] = controller
  end
end
