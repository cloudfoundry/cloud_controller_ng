require 'services/api'

module VCAP::CloudController
  class ManagedServiceInstancesController < RestController::ModelController
    allow_unauthenticated_access

    get "/v2/managed_service_instances/:guid", :read
    def read(guid)
      redirect "v2/service_instances/#{guid}"
    end
  end
end
