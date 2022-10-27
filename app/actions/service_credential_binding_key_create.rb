require 'actions/mixins/service_credential_binding_validation_create'

module VCAP::CloudController
  module V3
    class ServiceCredentialBindingKeyCreate < V3::ServiceBindingCreate
      include ServiceCredentialBindingCreateMixin

      def initialize(user_audit_info, audit_hash)
        super()
        @user_audit_info = user_audit_info
        @audit_hash = audit_hash
        @manifest_triggered = false
      end

      PERMITTED_BINDING_ATTRIBUTES = [:credentials].freeze

      def precursor(service_instance, message:)
        validate_service_instance!(service_instance)
        key = ServiceKey.first(service_instance: service_instance, name: message.name)
        validate_key!(key, message.name)

        binding_details = {
          service_instance: service_instance,
          name: message.name,
          credentials: {}
        }

        ServiceKey.new.tap do |b|
          ServiceKey.db.transaction do
            key.destroy if key
            b.save_with_attributes_and_new_operation(
              binding_details,
              CREATE_INITIAL_OPERATION
            )
            MetadataUpdate.update(b, message)
          end
        end
      rescue Sequel::ValidationFailed => e
        key_validation_error!(
          e,
          name: message.name,
          validation_error_handler: ValidationErrorHandler.new
        )
      end

      private

      def validate_service_instance!(service_instance)
        if service_instance.managed_instance?
          service_not_bindable! unless service_instance.service_plan.bindable?
          service_instance_not_found! if service_instance.create_failed?
          operation_in_progress! if service_instance.operation_in_progress?
        else
          key_not_supported_for_user_provided_service!
        end
      end

      def validate_key!(key, message_name)
        if key
          key_already_exists!(message_name) if key.create_succeeded? || key.create_in_progress?
          key_incomplete_deletion!(message_name) if key.delete_failed? || key.delete_in_progress?
        end
      end

      def permitted_binding_attributes
        PERMITTED_BINDING_ATTRIBUTES
      end

      def event_repository
        @event_repository ||= Repositories::ServiceGenericBindingEventRepository.new(
          Repositories::ServiceGenericBindingEventRepository::SERVICE_KEY_CREDENTIAL_BINDING)
      end

      def key_not_supported_for_user_provided_service!
        raise UnprocessableCreate.new("Service credential bindings of type 'key' are not supported for user-provided service instances.")
      end

      def key_already_exists!(key_name)
        raise UnprocessableCreate.new("The binding name is invalid. Key binding names must be unique. The service instance already has a key binding with name '#{key_name}'.")
      end

      def key_incomplete_deletion!(key_name)
        raise UnprocessableCreate.new('The binding name is invalid. Key binding names must be unique. '\
                                      "The service instance already has a key binding with the name '#{key_name}' that is getting deleted or its deletion failed.")
      end

      def service_not_bindable!
        raise UnprocessableCreate.new('Service plan does not allow bindings.')
      end

      def service_not_available!
        raise UnprocessableCreate.new('Service plan is not available.')
      end

      def volume_mount_not_enabled!
        raise UnprocessableCreate.new('Support for volume mount services is disabled.')
      end

      class ValidationErrorHandler
        def error!(message)
          raise ServiceCredentialBindingKeyCreate::UnprocessableCreate.new(message)
        end
      end
    end
  end
end
