require 'cloud_controller/rest_controller'

module VCAP::CloudController
  rest_controller :ProvidedServiceInstance do
    permissions_required do
      full Permissions::SpaceDeveloper
      full Permissions::CFAdmin
      read Permissions::SpaceAuditor
    end

    define_attributes do
      attribute :name, String
      attribute :credentials, Hash

      to_one :space
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
