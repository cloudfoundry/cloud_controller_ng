require 'services/service_brokers/service_client_provider'
require 'actions/v3/service_binding_delete'

module VCAP::CloudController
  module V3
    class ServiceRouteBindingDelete < V3::ServiceBindingDelete
      def initialize(service_event_repository, user_audit_info)
        super()
        @service_event_repository = service_event_repository
        @user_audit_info = user_audit_info
      end

      private

      attr_reader :service_event_repository

      def binding_event_repository
        Repositories::ServiceGenericBindingEventRepository.new('service_route_binding')
      end

      def perform_delete_actions(binding)
        record_audit_event(binding)
        binding.destroy
        binding.notify_diego
      end

      def perform_start_delete_actions(binding)
        binding_event_repository.record_start_delete(binding, @user_audit_info)
      end

      def record_audit_event(binding)
        service_event_repository.record_service_instance_event(
          :unbind_route,
          binding.service_instance,
          { route_guid: binding.route.guid },
        )

        binding_event_repository.record_delete(
          binding,
          @user_audit_info
        )
      end
    end
  end
end
