require 'jobs/reoccurring_job'
require 'actions/service_credential_binding_create'
require 'cloud_controller/errors/api_error'

module VCAP::CloudController
  module V3
    class CreateServiceCredentialBindingJobActor
      def display_name
        'service_bindings.create'
      end

      def resource_type
        'service_credential_binding'
      end

      def get_resource(resource_id)
        ServiceBinding.first(guid: resource_id)
      end
    end
  end
end
