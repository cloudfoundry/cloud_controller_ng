require 'services/api'

module VCAP::CloudController
  class ManagedServiceInstancesController < RestController::ModelController
    allow_unauthenticated_access

    deprecated_endpoint '/v2/managed_service_instance'

    get '/v2/managed_service_instances/:guid', :read
    def read(guid)
      redirect "v2/service_instances/#{guid}"
    end
  end
end
