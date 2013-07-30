require 'services/api'
require_relative 'service_validator'

module VCAP::CloudController
  rest_controller :ServiceBindings do
    permissions_required do
      full Permissions::CFAdmin
      read Permissions::OrgManager
      create Permissions::SpaceDeveloper
      read   Permissions::SpaceDeveloper
      delete Permissions::SpaceDeveloper
      read Permissions::SpaceAuditor
    end

    define_attributes do
      to_one    :app
      to_one    :service_instance
      attribute :binding_options, Hash, :default => {}
    end

    query_parameters :app_guid, :service_instance_guid

    def self.translate_validation_exception(e, attributes)
      unique_errors = e.errors.on([:app_id, :service_instance_id])
      if unique_errors && unique_errors.include?(:unique)
        Errors::ServiceBindingAppServiceTaken.new(
          "#{attributes["app_guid"]} #{attributes["service_instance_guid"]}")
      else
        Errors::ServiceBindingInvalid.new(e.errors.full_messages)
      end
    end

    def create_object
      instance = Models::ServiceInstance.find(guid: request_attrs.fetch('service_instance_guid'))
      instance.create_binding(request_attrs.fetch('app_guid'), request_attrs.fetch('binding_options'))
    end
  end
end
