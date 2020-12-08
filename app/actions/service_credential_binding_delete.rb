require 'actions/v3/service_binding_delete'
require 'repositories/service_generic_binding_event_repository'

module VCAP::CloudController
  module V3
    class ServiceCredentialBindingDelete < V3::ServiceBindingDelete
      EVENT_REPOSITORY_TYPES = {
        key: Repositories::ServiceGenericBindingEventRepository::SERVICE_KEY_CREDENTIAL_BINDING,
        credential: Repositories::ServiceGenericBindingEventRepository::SERVICE_APP_CREDENTIAL_BINDING
      }.freeze

      def initialize(type, user_audit_info)
        super()
        @user_audit_info = user_audit_info
        @event_repository_type = EVENT_REPOSITORY_TYPES[type]
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
        @event_repository ||= Repositories::ServiceGenericBindingEventRepository.new(@event_repository_type)
      end
    end
  end
end
