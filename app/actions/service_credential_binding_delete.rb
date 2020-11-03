require 'actions/v3/service_binding_delete'

module VCAP::CloudController
  module V3
    class ServiceCredentialBindingDelete < V3::ServiceBindingDelete
      def initialize(user_audit_info)
        super()
        @user_audit_info = user_audit_info
      end

      private

      def perform_delete_actions(binding)
        binding.destroy

        event_repository.record_delete(binding, @user_audit_info)
      end

      def perform_start_delete_actions(binding)
        event_repository.record_start_delete(binding, @user_audit_info)
      end

      def event_repository
        Repositories::ServiceBindingEventRepository
      end
    end
  end
end
