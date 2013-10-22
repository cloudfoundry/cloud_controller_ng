require 'cloud_controller/rest_controller'

module VCAP::CloudController
  rest_controller :UserProvidedServiceInstances do
    define_attributes do
      attribute :name, String
      attribute :credentials, Hash

      to_one :space
      to_many :service_bindings
    end

    def self.translate_validation_exception(e, attributes)
      space_and_name_errors = e.errors.on([:space_id, :name])
      if space_and_name_errors && space_and_name_errors.include?(:unique)
        Errors::ServiceInstanceNameTaken.new(attributes["name"])
      else
        Errors::ServiceInstanceInvalid.new(e.errors.full_messages)
      end
    end
  end
end
