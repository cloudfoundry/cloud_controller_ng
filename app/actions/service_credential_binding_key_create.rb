require 'actions/mixins/service_credential_binding_validation_create'

module VCAP::CloudController
  module V3
    class ServiceCredentialBindingKeyCreate < V3::ServiceBindingCreate
      include ServiceCredentialBindingCreateMixin

      class UnprocessableCreate < StandardError
      end

      def initialize(user_audit_info, audit_hash)
        super()
        @user_audit_info = user_audit_info
        @audit_hash = audit_hash
      end

      PERMITTED_BINDING_ATTRIBUTES = [:credentials].freeze

      def precursor(service_instance, name)
        validate!(service_instance)

        binding_details = {
          service_instance: service_instance,
          name: name,
          credentials: {}
        }

        ServiceKey.new(**binding_details).tap do |b|
          b.save_with_new_operation(
            {
              type: 'create',
              state: 'in progress',
            }
          )
        end

      rescue Sequel::ValidationFailed => e
        key_validation_error!(
          e,
          name: name,
          validation_error_handler: ValidationErrorHandler.new
        )
      end

      private

      def validate!(service_instance)
        if service_instance.managed_instance?
          service_not_bindable! unless service_instance.service_plan.bindable?
          service_not_available! unless service_instance.service_plan.active?
          operation_in_progress! if service_instance.operation_in_progress?
        else
          key_not_supported_for_user_provided_service!
        end
      end

      def complete_binding_and_save(binding, binding_details, last_operation)
        binding.save_with_attributes_and_new_operation(
          binding_details.symbolize_keys.slice(*PERMITTED_BINDING_ATTRIBUTES),
          {
            type: 'create',
            state: last_operation[:state],
            description: last_operation[:description]
          }
        )
        event_repository.record_create(binding, @user_audit_info, @audit_hash, manifest_triggered: false)
      end

      def save_incomplete_binding(binding, broker_operation)
        binding.save_with_attributes_and_new_operation(
          {},
          {
            type: 'create',
            state: 'in progress',
            broker_provided_operation: broker_operation
          }
        )
        event_repository.record_start_create(binding, @user_audit_info, @audit_hash, manifest_triggered: false)
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

      def operation_in_progress!
        raise UnprocessableCreate.new('There is an operation in progress for the service instance.')
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
          raise UnprocessableCreate.new(message)
        end
      end
    end
  end
end
