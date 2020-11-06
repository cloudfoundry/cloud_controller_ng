require 'services/service_brokers/service_client_provider'
require 'actions/v3/service_binding_delete'

module VCAP::CloudController
  module V3
    class ServiceRouteBindingDelete < V3::ServiceBindingDelete
      def initialize(user_audit_info)
        super()
        @user_audit_info = user_audit_info
      end

      private

      def event_repository
        @event_repository ||= Repositories::ServiceGenericBindingEventRepository.new(
          Repositories::ServiceGenericBindingEventRepository::SERVICE_ROUTE_BINDING)
      end

      def perform_delete_actions(binding)
        event_repository.record_delete(
          binding,
          @user_audit_info
        )

        binding.destroy
        binding.notify_diego
      end

      def perform_start_delete_actions(binding)
        event_repository.record_start_delete(binding, @user_audit_info)
      end
    end
  end
end
