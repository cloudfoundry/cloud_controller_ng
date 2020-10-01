require 'jobs/v3/create_route_binding_job'
require 'jobs/v3/create_service_credential_binding_job'

class CreateServiceBindingFactory
  def self.for(type)
    if type == :route
      CreateRouteBindingJobActor.new
    else
      CreateServiceCredentialBindingJobActor.new
    end
  end
end
