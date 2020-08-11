require 'jobs/v3/update_service_instance_job'
require 'repositories/service_event_repository'

module VCAP::CloudController
  class ServiceInstanceUpdateManaged
    class InvalidServiceInstance < StandardError
    end

    class UnprocessableUpdate < CloudController::Errors::ApiError
    end

    def initialize(service_event_repository)
      @service_event_repository = service_event_repository
    end

    def update(service_instance, message)
      updater = Updater.new(service_instance, message)

      updater.raise_if_cannot_proceed!

      begin
        lock = UpdaterLock.new(service_instance)
        lock.lock!

        if updater.update_broker_needed?
          job = updater.update_async(service_event_repository.user_audit_info)
          service_event_repository.record_service_instance_event(:start_update, service_instance, message.audit_hash)
          lock.asynchronous_unlock!
          return nil, job
        else
          si = updater.update_sync
          service_event_repository.record_service_instance_event(:update, service_instance, message.audit_hash)
          lock.synchronous_unlock!
          return si, nil
        end
      ensure
        lock.unlock_and_fail! if lock.needs_unlock?
      end
    end

    private

    attr_reader :service_event_repository

    class Updater
      attr_reader :service_instance, :message

      def initialize(service_instance, message)
        @service_instance = service_instance
        @message = message
      end

      def raise_if_cannot_proceed!
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
        logger = Steno.logger('cc.action.service_instance_update')

        service_instance.db.transaction do
          service_instance.update(message.updates) if message.updates.any?
          MetadataUpdate.update(service_instance, message)
        end

        logger.info("Finished updating service_instance #{service_instance.guid}")
        return service_instance
      rescue Sequel::ValidationFailed => e
        raise InvalidServiceInstance.new(e.message)
      end

      def update_async(user_audit_info)
        logger = Steno.logger('cc.action.service_instance_update')

        update_job = V3::UpdateServiceInstanceJob.new(
          service_instance.guid,
          message: message,
          request_attr: message.audit_hash,
          user_audit_info: user_audit_info
        )
        pollable_job = Jobs::Enqueuer.new(update_job, queue: Jobs::Queues.generic).enqueue_pollable

        logger.info("Queued job #{pollable_job.guid} to update service_instance #{service_instance.guid}")

        return pollable_job
      end

      private

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
        return unless service_instance.service_bindings.any?
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

      def maintenance_info_match(message, object)
        return false if object.maintenance_info.nil? && !message.maintenance_info.nil?

        message.maintenance_info_version == object.maintenance_info['version']
      end
    end
  end
end
