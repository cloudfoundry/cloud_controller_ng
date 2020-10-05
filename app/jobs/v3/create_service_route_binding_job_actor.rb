require 'jobs/reoccurring_job'
require 'actions/service_route_binding_create'
require 'cloud_controller/errors/api_error'

module VCAP::CloudController
  module V3
    class CreateServiceRouteBindingJobActor
      def display_name
        'service_route_bindings.create'
      end

      def resource_type
        'service_route_binding'
      end

      def get_resource(resource_id)
        RouteBinding.first(guid: resource_id)
      end
    end
  end
end
