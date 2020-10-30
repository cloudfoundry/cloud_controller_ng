require 'services/service_brokers/service_client_provider'
require 'actions/v3/service_binding_delete'

module VCAP::CloudController
  module V3
    class ServiceRouteBindingDelete < V3::ServiceBindingDelete
      def initialize(service_event_repository)
        super()
        @service_event_repository = service_event_repository
      end

      private

      attr_reader :service_event_repository

      def perform_delete_actions(binding)
        record_audit_event(binding)
        binding.destroy
        binding.notify_diego
      end

      def record_audit_event(binding)
        service_event_repository.record_service_instance_event(
          :unbind_route,
          binding.service_instance,
          { route_guid: binding.route.guid },
        )
      end
    end
  end
end
