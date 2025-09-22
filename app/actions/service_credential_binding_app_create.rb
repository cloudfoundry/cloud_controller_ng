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

      PERMITTED_BINDING_ATTRIBUTES = %i[credentials syslog_drain_url volume_mounts].freeze

      def precursor(service_instance, message:, app: nil, volume_mount_services_enabled: false)
        validate_service_instance!(app, service_instance, volume_mount_services_enabled)

        new_binding_details = {
          service_instance: service_instance,
          name: message.name,
          app: app,
          type: 'app',
          credentials: {}
        }

        ServiceBinding.new.tap do |new_binding|
          ServiceBinding.db.transaction do
            # Lock the app to ensure no other bindings are created concurrently and rules can be enforced
            # - number of bindings per service instance is below limit
            # - no other binding (to other service instance) for this app has the same name
            app.lock!

            num_valid_bindings = 0
            existing_bindings = ServiceBinding.where(service_instance:, app:)
            existing_bindings.each do |binding|
              if binding.create_failed?
                binding.destroy
                VCAP::Services::ServiceBrokers::V2::OrphanMitigator.new.cleanup_failed_bind(binding)
                next
              end

              validate_binding!(binding, desired_binding_name: message.name)
              num_valid_bindings += 1
            end

            validate_number_of_bindings!(num_valid_bindings)
            validate_app_guid_name_uniqueness!(app.guid, message.name, service_instance.guid)

            new_binding.save_with_attributes_and_new_operation(
              new_binding_details,
              CREATE_INITIAL_OPERATION
            )
            MetadataUpdate.update(new_binding, message)
          end
        end
      rescue Sequel::ValidationFailed => e
        raise UnprocessableCreate.new(e.full_message)
      end

      private

      def validate_service_instance!(app, service_instance, volume_mount_services_enabled)
        app_is_required! if app.blank?
        space_mismatch! unless all_space_guids(service_instance).include? app.space_guid
        return unless service_instance.managed_instance?

        service_not_bindable! unless service_instance.service_plan.bindable?
        volume_mount_not_enabled! if service_instance.volume_service? && !volume_mount_services_enabled
        service_instance_not_found! if service_instance.create_failed?
        operation_in_progress! if service_instance.operation_in_progress?
      end

      def validate_binding!(binding, desired_binding_name:)
        already_bound! if max_bindings_per_app_service_instance == 1 && (binding.create_succeeded? || binding.create_in_progress?)
        binding_in_progress!(binding.guid) if binding.create_in_progress?
        incomplete_deletion! if binding.delete_in_progress? || binding.delete_failed?
        name_cannot_be_changed! if binding.name != desired_binding_name
      end

      def validate_number_of_bindings!(number_of_bindings)
        too_many_bindings! if number_of_bindings >= max_bindings_per_app_service_instance
      end

      def validate_app_guid_name_uniqueness!(target_app_guid, desired_binding_name, target_service_instance_guid)
        return if desired_binding_name.nil?

        return unless ServiceBinding.where(app_guid: target_app_guid, name: desired_binding_name).exclude(service_instance_guid: target_service_instance_guid).any?

        name_uniqueness_violation!(desired_binding_name)
      end

      def permitted_binding_attributes
        PERMITTED_BINDING_ATTRIBUTES
      end

      def all_space_guids(service_instance)
        (service_instance.shared_spaces + [service_instance.space]).map(&:guid)
      end

      def event_repository
        @event_repository ||= Repositories::ServiceGenericBindingEventRepository.new(
          Repositories::ServiceGenericBindingEventRepository::SERVICE_APP_CREDENTIAL_BINDING
        )
      end

      def max_bindings_per_app_service_instance
        VCAP::CloudController::Config.config.get(:max_service_credential_bindings_per_app_service_instance)
      end

      def app_is_required!
        raise UnprocessableCreate.new('No app was specified')
      end

      def binding_in_progress!(binding_guid)
        raise UnprocessableCreate.new("There is already a binding in progress for this service instance and app (binding guid: #{binding_guid})")
      end

      def too_many_bindings!
        raise UnprocessableCreate.new(
          "The app has too many bindings to this service instance (limit: #{max_bindings_per_app_service_instance}). Consider deleting existing/orphaned bindings."
        )
      end

      def name_cannot_be_changed!
        raise UnprocessableCreate.new('The binding name cannot be changed for the same app and service instance')
      end

      def name_uniqueness_violation!(name)
        msg = 'The binding name is invalid. Binding names must be unique for a given service instance and app.'
        msg += " The app already has a binding with name '#{name}'." unless name.nil? || name.empty?

        raise UnprocessableCreate.new(msg)
      end

      def already_bound!
        raise UnprocessableCreate.new('The app is already bound to the service instance')
      end

      def incomplete_deletion!
        raise UnprocessableCreate.new('The binding is getting deleted or its deletion failed') if max_bindings_per_app_service_instance == 1

        raise UnprocessableCreate.new('A binding for this service instance and app is getting deleted or its deletion failed')
      end

      def space_mismatch!
        raise UnprocessableCreate.new('The service instance and the app are in different spaces')
      end

      def service_not_bindable!
        raise UnprocessableCreate.new('Service plan does not allow bindings')
      end

      def volume_mount_not_enabled!
        raise UnprocessableCreate.new('Support for volume mount services is disabled')
      end
    end
  end
end
