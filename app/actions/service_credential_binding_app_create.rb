require 'repositories/service_generic_binding_event_repository'
require 'services/service_brokers/service_client_provider'
require 'actions/v3/service_binding_create'

module VCAP::CloudController
  module V3
    class ServiceCredentialBindingAppCreate < V3::ServiceBindingCreate
      class Unimplemented < StandardError
      end

      def initialize(user_audit_info, audit_hash, manifest_triggered: false)
        super()
        @user_audit_info = user_audit_info
        @audit_hash = audit_hash
        @manifest_triggered = manifest_triggered
      end

      PERMITTED_BINDING_ATTRIBUTES = [:credentials, :syslog_drain_url, :volume_mounts].freeze

      def precursor(service_instance, app: nil, volume_mount_services_enabled: false, message:)
        validate_service_instance!(app, service_instance, volume_mount_services_enabled)
        binding = ServiceBinding.first(service_instance: service_instance, app: app)
        validate_binding!(binding)

        binding_details = {
          service_instance: service_instance,
          name: message.name,
          app: app,
          type: 'app',
          credentials: {}
        }

        ServiceBinding.new.tap do |b|
          ServiceBinding.db.transaction do
            binding.destroy if binding
            b.save_with_attributes_and_new_operation(
              binding_details,
              CREATE_INITIAL_OPERATION
            )
            MetadataUpdate.update(b, message)
          end
        end
      rescue Sequel::ValidationFailed, Sequel::UniqueConstraintViolation => e
        raise UnprocessableCreate.new(e.full_message)
      end

      private

      def validate_service_instance!(app, service_instance, volume_mount_services_enabled)
        app_is_required! unless app.present?
        space_mismatch! unless all_space_guids(service_instance).include? app.space_guid
        if service_instance.managed_instance?
          service_not_bindable! unless service_instance.service_plan.bindable?
          volume_mount_not_enabled! if service_instance.volume_service? && !volume_mount_services_enabled
          service_instance_not_found! if service_instance.create_failed?
          operation_in_progress! if service_instance.operation_in_progress?
        end
      end

      def validate_binding!(binding)
        if binding
          already_bound! if binding.create_succeeded? || binding.create_in_progress?
          incomplete_deletion! if binding.delete_failed? || binding.delete_in_progress?
        end
      end

      def permitted_binding_attributes
        PERMITTED_BINDING_ATTRIBUTES
      end

      def all_space_guids(service_instance)
        (service_instance.shared_spaces + [service_instance.space]).map(&:guid)
      end

      def event_repository
        @event_repository ||= Repositories::ServiceGenericBindingEventRepository.new(
          Repositories::ServiceGenericBindingEventRepository::SERVICE_APP_CREDENTIAL_BINDING)
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

      def incomplete_deletion!
        raise UnprocessableCreate.new('The binding is getting deleted or its deletion failed')
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
