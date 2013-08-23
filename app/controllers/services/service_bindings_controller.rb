require 'services/api'

module VCAP::CloudController
  rest_controller :ServiceBindings do
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
  end
end
