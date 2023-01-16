require 'services/service_brokers/service_client_provider'
require 'actions/metadata_update'
require 'cloud_controller/errors/api_error'

module VCAP::CloudController
  module V3
    class ServiceInstanceUpdateManaged
      class UnprocessableUpdate < CloudController::Errors::ApiError; end
      class InvalidServiceInstance < StandardError
      end
      class LastOperationFailedState < StandardError; end

      PollingStatus = Struct.new(:finished, :retry_after).freeze
      PollingFinished = PollingStatus.new(true, nil).freeze
      ContinuePolling = ->(retry_after) { PollingStatus.new(false, retry_after) }

      UPDATE_IN_PROGRESS_OPERATION = { type: 'update', state: 'in progress' }.freeze

      def initialize(instance, message, user_audit_info, audit_hash)
        @service_instance = instance
        @message = message
        @user_audit_info = user_audit_info
        @audit_hash = audit_hash
      end

      def preflight!
        raise_if_invalid_state!
        raise_if_invalid_update!
        raise_if_renaming_shared_service_instance!
        raise_if_invalid_plan_change!
        raise_if_invalid_maintenance_info_change!
        raise_if_cannot_update!
      end

      def update_broker_needed?
        service_name_changed = message.requested?(:name) && service_instance.service.allow_context_updates
        parameters_changed = message.requested?(:parameters)
        service_plan_changed = message.service_plan_guid &&
          message.service_plan_guid != service_instance.service_plan.guid

        maintenance_info_changed = message.maintenance_info_version &&
          message.maintenance_info_version != service_instance.maintenance_info&.fetch('version', nil)

        service_name_changed || parameters_changed || service_plan_changed || maintenance_info_changed
      end

      def update_sync
        if update_metadata_only?
          service_instance.db.transaction do
            MetadataUpdate.update(service_instance, message)
          end
          event_repository.record_service_instance_event(:update, service_instance, message.audit_hash)
        else
          lock = UpdaterLock.new(service_instance)
          lock.lock!

          begin
            original_service_instance = service_instance.dup
            service_instance.db.transaction do
              service_instance.update(message.updates) if message.updates.any?
              MetadataUpdate.update(service_instance, message)
            end
            event_repository.record_service_instance_event(:update, original_service_instance, message.audit_hash)
            lock.synchronous_unlock!
          rescue Sequel::ValidationFailed => e
            raise InvalidServiceInstance.new(e.message)
          ensure
            lock.unlock_and_fail! if lock.present? && lock.needs_unlock?
          end
        end

        service_instance
      end

      def enqueue_update
        lock = UpdaterLock.new(service_instance)
        lock.lock!

        begin
          update_job = VCAP::CloudController::V3::UpdateServiceInstanceJob.new(
            service_instance.guid,
            message: message,
            user_audit_info: user_audit_info,
            audit_hash: message.audit_hash
          )
          pollable_job = Jobs::Enqueuer.new(update_job, queue: Jobs::Queues.generic).enqueue_pollable
          lock.asynchronous_unlock!
        ensure
          lock.unlock_and_fail! if lock.present? && lock.needs_unlock?
        end

        pollable_job
      end

      def update(accepts_incomplete: false)
        client = VCAP::Services::ServiceClientProvider.provide(instance: service_instance)
        details, err = client.update(
          service_instance,
          service_plan,
          accepts_incomplete: accepts_incomplete,
          arbitrary_parameters: message.parameters || {},
          previous_values: previous_values,
          maintenance_info: maintenance_info,
          name: message.requested?(:name) ? message.name : service_instance.name,
          user_guid: user_audit_info.user_guid
        )
        raise err if err

        if details[:last_operation][:state] == 'in progress'
          save_incomplete_instance(service_instance, details)
        else
          complete_instance_and_save(service_instance, details)
        end
      rescue => e
        save_failed_state(service_instance, e)

        raise e
      end

      def poll
        client = VCAP::Services::ServiceClientProvider.provide(instance: service_instance)
        details = client.fetch_service_instance_last_operation(service_instance, user_guid: user_audit_info.user_guid)

        case details[:last_operation][:state]
        when 'succeeded'
          fetch_result = fetch_service_instance(client)
          complete_instance_and_save(service_instance, parse_response(fetch_result, details))
          return PollingFinished
        when 'in progress'
          save_last_operation(service_instance, details[:last_operation])
          ContinuePolling.call(details[:retry_after])
        when 'failed'
          save_last_operation(service_instance, details[:last_operation])
          raise LastOperationFailedState.new(details[:last_operation][:description])
        end
      rescue LastOperationFailedState => e
        raise e
      rescue => e
        save_failed_state(service_instance, e)
        raise e
      end

      private

      attr_reader :service_instance, :message, :user_audit_info

      def event_repository
        Repositories::ServiceEventRepository.new(user_audit_info)
      end

      def complete_instance_and_save(instance, broker_response)
        updates = message.updates.tap do |u|
          u[:service_plan_guid] = service_plan.guid
          u[:maintenance_info] = maintenance_info if maintenance_info_updated?
        end
        updates[:dashboard_url] = broker_response[:dashboard_url] if broker_response.key?(:dashboard_url)

        ManagedServiceInstance.db.transaction do
          service_instance.save_with_new_operation(
            updates,
            broker_response[:last_operation] || {}
          )
          MetadataUpdate.update(service_instance, message)
        end

        event_repository.record_service_instance_event(:update, instance, @audit_hash)
      end

      def save_incomplete_instance(instance, broker_response)
        attributes_to_update = {}
        attributes_to_update[:dashboard_url] = broker_response[:dashboard_url] if broker_response.key?(:dashboard_url)

        instance.save_with_new_operation(
          attributes_to_update,
          broker_response[:last_operation] || {}
        )

        event_repository.record_service_instance_event(:start_update, instance, @audit_hash)
      end

      def save_failed_state(instance, e)
        instance.save_with_new_operation(
          {},
          {
            type: 'update',
            state: 'failed',
            description: e.message,
          }
        )
      end

      def save_last_operation(instance, last_operation)
        instance.save_with_new_operation(
          {},
          {
            type: 'update',
            state: last_operation[:state],
            description: last_operation[:description],
            broker_provided_operation: instance.last_operation.broker_provided_operation
          }
        )
      end

      def fetch_service_instance(client)
        logger = Steno.logger('cc.action.service_instance_update_managed')

        fetch_result = {}
        begin
          if service_plan.service.instances_retrievable
            fetch_result = client.fetch_service_instance(service_instance, user_guid: user_audit_info.user_guid)
          end
        rescue => e
          logger.info('fetch-service-instance-failed', error: e.class.name, error_message: e.message)
        end

        fetch_result
      end

      def update_metadata_only?
        !is_deleting?(service_instance) && only_metadata?
      end

      def is_deleting?(service_instance)
        service_instance.operation_in_progress? && service_instance.last_operation[:type] == 'delete'
      end

      def only_metadata?
        message.requested_keys.one? && message.requested?(:metadata)
      end

      def service_plan
        plan = if message.service_plan_guid
                 ServicePlan.first(guid: message.service_plan_guid)
               else
                 service_instance.service_plan
               end

        service_plan_gone!(message.service_plan_guid) unless plan
        plan
      end

      def service_plan_gone!(plan_id)
        raise CloudController::Errors::ApiError.new_from_details('ServicePlanNotFound', plan_id)
      end

      def previous_values
        {
          plan_id: service_instance.service_plan.broker_provided_id,
          service_id: service_instance.service.broker_provided_id,
          organization_id: service_instance.organization.guid,
          space_id: service_instance.space.guid,
          maintenance_info: service_instance.maintenance_info
        }
      end

      def raise_if_cannot_proceed!
        raise_if_invalid_update!
        raise_if_renaming_shared_service_instance!
        raise_if_invalid_plan_change!
        raise_if_invalid_maintenance_info_change!
        raise_if_cannot_update!
      end

      def raise_if_invalid_update!
        return unless message.updates.any?

        service_instance.set(message.updates)
        return service_instance.reload if service_instance.valid?

        service_instance_name_errors = service_instance.errors.on(:name).to_a
        service_plan_errors = service_instance.errors.on(:service_plan).to_a

        if service_instance_name_errors.include?(:unique)
          raise UnprocessableUpdate.new_from_details('ServiceInstanceNameTaken', message.name)
        elsif service_plan_errors.include?(:paid_services_not_allowed_by_space_quota)
          raise UnprocessableUpdate.new_from_details('ServiceInstanceServicePlanNotAllowedBySpaceQuota')
        elsif service_plan_errors.include?(:paid_services_not_allowed_by_quota)
          raise UnprocessableUpdate.new_from_details('ServiceInstanceServicePlanNotAllowed')
        end

        raise Sequel::ValidationFailed.new(service_instance)
      end

      def raise_if_renaming_shared_service_instance!
        return unless message.requested?(:name)
        return unless service_instance.shared?

        raise UnprocessableUpdate.new_from_details('SharedServiceInstanceCannotBeRenamed')
      end

      def raise_if_invalid_plan_change!
        raise_if_plan_not_updateable!
        raise_if_bind_inconsistency!
      end

      def raise_if_plan_not_updateable!
        return unless message.service_plan_guid
        return if service_instance.service_plan.plan_updateable?

        raise UnprocessableUpdate.new_from_details('ServicePlanNotUpdateable')
      end

      def raise_if_bind_inconsistency!
        return unless message.service_plan_guid
        return unless service_instance.service_bindings_dataset.any?
        return if ServicePlan.first(guid: message.service_plan_guid).bindable?

        raise UnprocessableUpdate.new_from_details(
          'ServicePlanInvalid',
          'cannot switch to non-bindable plan when service bindings exist'
        )
      end

      def raise_if_invalid_maintenance_info_change!
        return unless message.maintenance_info_version

        raise_if_concurrent_plan_update!
        raise_if_unsupported_by_current_plan!
        raise_if_version_mismatch!
      end

      def raise_if_concurrent_plan_update!
        return unless message.service_plan_guid
        return if message.service_plan_guid == service_instance.service_plan.guid

        raise UnprocessableUpdate.new_from_details('MaintenanceInfoNotUpdatableWhenChangingPlan')
      end

      def raise_if_unsupported_by_current_plan!
        return if service_instance.service_plan.maintenance_info

        raise UnprocessableUpdate.new_from_details('MaintenanceInfoNotSupported')
      end

      def raise_if_version_mismatch!
        is_plan_version = maintenance_info_match(message, service_instance.service_plan)
        is_current_version = service_instance.maintenance_info && maintenance_info_match(message, service_instance)
        return if is_plan_version || is_current_version

        raise UnprocessableUpdate.new_from_details('MaintenanceInfoConflict')
      end

      def raise_if_cannot_update!
        error_code = 'ServiceInstanceWithInaccessiblePlanNotUpdateable'.freeze
        update_error = ->(x) { UnprocessableUpdate.new_from_details(error_code, x) }
        unless service_instance.service_plan.active?
          raise update_error.call('parameters') unless message.parameters.nil?
          raise update_error.call('name') if service_instance.service_plan.service.allow_context_updates && !message.name.nil?
          raise update_error.call('maintenance_info') unless message.maintenance_info.nil? || maintenance_info_match(message, service_instance)
        end
      end

      def raise_if_invalid_state!
        if service_instance.create_failed?
          raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceNotFound', service_instance.name)
        end
      end

      def maintenance_info_match(message, object)
        return false if object.maintenance_info.nil? && !message.maintenance_info.nil?

        message.maintenance_info_version == object.maintenance_info['version']
      end

      def maintenance_info
        plan_change_requested = service_plan.guid != service_instance.service_plan.guid

        info = if plan_change_requested
                 service_plan.maintenance_info&.symbolize_keys
               else
                 message.maintenance_info
               end

        info&.slice(:version)
      end

      def maintenance_info_updated?
        plan_change_requested = service_plan.guid != service_instance.service_plan.guid
        plan_change_requested || message.maintenance_info
      end

      def parse_response(fetch_instance, last_operation)
        response = {
          last_operation: {
            state: last_operation[:last_operation][:state],
            type: 'update',
            description: last_operation[:last_operation][:description]
          }
        }
        response[:dashboard_url] = fetch_instance[:dashboard_url] if fetch_instance.key?(:dashboard_url)
        response
      end

      def unprocessable_service_plan!
        unprocessable!('Invalid service plan. Ensure that the service plan exists, is available, and you have access to it.')
      end

      class ValidationErrorHandler
        def error!(message)
          raise InvalidManagedServiceInstance.new(message)
        end
      end
    end
  end
end
