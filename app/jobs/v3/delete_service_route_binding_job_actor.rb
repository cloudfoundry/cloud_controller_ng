require 'jobs/reoccurring_job'
require 'cloud_controller/errors/api_error'

module VCAP::CloudController
  module V3
    class DeleteServiceRouteBindingJobActor
      def display_name
        'service_route_bindings.delete'
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
