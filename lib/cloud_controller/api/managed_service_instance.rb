require 'services/api'

module VCAP::CloudController
  class ManagedServiceInstance < RestController::ModelController
    allow_unauthenticated_access

    def read(guid)
      redirect "v2/service_instances/#{guid}"
    end

    get '/v2/managed_service_instances/:guid', :read
  end
end
