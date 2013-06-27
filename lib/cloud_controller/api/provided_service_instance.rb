require 'cloud_controller/rest_controller'

module VCAP::CloudController
  class ProvidedServiceInstance < RestController::ModelController
    permissions_required do
      full Permissions::SpaceDeveloper
    end

    define_attributes do
      attribute :name, String
      attribute :credentials, Hash

      to_one :space
    end
    define_messages

    post '/v2/provided_service_instances', :create
  end
end
