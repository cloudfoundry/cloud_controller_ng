require 'repositories/service_binding_event_repository'
require 'services/service_brokers/service_client_provider'

module VCAP::CloudController
  module V3
    class ServiceCredentialBindingCreate
      class UnprocessableCreate < StandardError
      end

      class Unimplemented < StandardError
      end

      def initialize(user_audit_info, audit_hash)
        @user_audit_info = user_audit_info
        @audit_hash = audit_hash
      end

      def precursor(service_instance, app: nil, name: nil, volume_mount_services_enabled: false)
        validate!(service_instance, app, volume_mount_services_enabled)

        binding_details = {
          service_instance: service_instance,
          name: name,
          app: app,
          type: 'app',
          credentials: {}
        }

        ServiceBinding.new(**binding_details).tap do |b|
          b.save_with_new_operation(
            {
              type: 'create',
              state: 'in progress',
            }
          )
        end
      rescue Sequel::ValidationFailed => e
        already_bound! if e.message =~ /The app is already bound to the service/
        raise UnprocessableCreate.new(e.full_message)
      end

      def bind(binding, parameters: {}, accepts_incomplete: false)
        client = VCAP::Services::ServiceClientProvider.provide(instance: binding.service_instance)
        details = client.bind(binding, arbitrary_parameters: parameters, accepts_incomplete: accepts_incomplete)

        if details[:async]
          save_incomplete_binding(binding, details[:operation])
        else
          binding.save_with_new_operation(operation_succeeded, attributes: details[:binding])
          event_repository.record_create(binding, @user_audit_info, @audit_hash, manifest_triggered: false)
        end
      rescue => e
        binding.save_with_new_operation({
          type: 'create',
          state: 'failed',
          description: e.message,
        })
        raise e
      end

      private

      def operation_succeeded
        { type: 'create', state: 'succeeded' }
      end

      def save_incomplete_binding(binding, operation)
        binding.save_with_new_operation({
          type: 'create',
          state: 'in progress',
          broker_provided_operation: operation
        })
      end

      def validate!(service_instance, app, volume_mount_services_enabled)
        app_is_required! unless app.present?
        space_mismatch! unless all_space_guids(service_instance).include? app.space.guid

        if service_instance.managed_instance?
          service_not_bindable! unless service_instance.service_plan.bindable?
          service_not_available! unless service_instance.service_plan.active?
          volume_mount_not_enabled! if service_instance.volume_service? && !volume_mount_services_enabled
          operation_in_progress! if service_instance.operation_in_progress?
        end
      end

      def all_space_guids(service_instance)
        (service_instance.shared_spaces + [service_instance.space]).map(&:guid)
      end

      def event_repository
        Repositories::ServiceBindingEventRepository
      end

      def operation_in_progress!
        raise UnprocessableCreate.new('There is an operation in progress for the service instance')
      end

      def app_is_required!
        raise UnprocessableCreate.new('No app was specified')
      end

      def not_supported!
        raise Unimplemented.new('Cannot create credential bindings for managed service instances')
      end

      def already_bound!
        raise UnprocessableCreate.new('The app is already bound to the service instance')
      end

      def space_mismatch!
        raise UnprocessableCreate.new('The service instance and the app are in different spaces')
      end

      def service_not_bindable!
        raise UnprocessableCreate.new('Service plan does not allow bindings')
      end

      def service_not_available!
        raise UnprocessableCreate.new('Service plan is not available')
      end

      def volume_mount_not_enabled!
        raise UnprocessableCreate.new('Support for volume mount services is disabled')
      end
    end
  end
end
