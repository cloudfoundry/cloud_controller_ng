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
      raise_if_invalid_update!(service_instance, message)
      raise_if_renaming_shared_service_instance!(service_instance, message)
      raise_if_invalid_plan_change!(service_instance, message)
      raise_if_invalid_maintenance_info_change!(service_instance, message)

      begin
        lock = UpdaterLock.new(service_instance)
        lock.lock!

        if update_broker_needed?(service_instance, message)
          job = update_async(service_instance, message)
          lock.asynchronous_unlock!
          return nil, job
        else
          si = update_sync(service_instance, message)
          lock.synchronous_unlock!
          return si, nil
        end
      ensure
        lock.unlock_and_fail! if lock.needs_unlock?
      end
    end

    private

    attr_reader :service_event_repository

    def update_broker_needed?(service_instance, message)
      service_name_changed = message.requested?(:name) && service_instance.service.allow_context_updates
      parameters_changed = message.requested?(:parameters)
      service_plan_changed = message.service_plan_guid &&
        message.service_plan_guid != service_instance.service_plan.guid

      maintenance_info_changed = message.maintenance_info_version &&
        message.maintenance_info_version != service_instance.maintenance_info&.fetch('version', nil)

      service_name_changed || parameters_changed || service_plan_changed || maintenance_info_changed
    end

    def update_sync(service_instance, message)
      logger = Steno.logger('cc.action.service_instance_update')

      service_instance.db.transaction do
        service_instance.update(message.updates) if message.updates.any?
        MetadataUpdate.update(service_instance, message)
        service_event_repository.record_service_instance_event(:update, service_instance, message.audit_hash)
      end

      logger.info("Finished updating service_instance #{service_instance.guid}")
      return service_instance
    rescue Sequel::ValidationFailed => e
      raise InvalidServiceInstance.new(e.message)
    end

    def update_async(service_instance, message)
      logger = Steno.logger('cc.action.service_instance_update')

      update_job = V3::UpdateServiceInstanceJob.new(
        service_instance.guid,
        message: message,
        user_audit_info: service_event_repository.user_audit_info
      )
      pollable_job = Jobs::Enqueuer.new(update_job, queue: Jobs::Queues.generic).enqueue_pollable

      logger.info("Queued job #{pollable_job.guid} to update service_instance #{service_instance.guid}")
      service_event_repository.record_service_instance_event(:start_update, service_instance, message.audit_hash)

      return pollable_job
    end

    def raise_if_invalid_update!(service_instance, message)
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

    def raise_if_renaming_shared_service_instance!(service_instance, message)
      return unless message.requested?(:name)
      return unless service_instance.shared?

      raise UnprocessableUpdate.new_from_details('SharedServiceInstanceCannotBeRenamed')
    end

    def raise_if_invalid_plan_change!(service_instance, message)
      raise_if_plan_not_updateable!(service_instance, message)
      raise_if_bind_inconsistency!(service_instance, message)
    end

    def raise_if_plan_not_updateable!(service_instance, message)
      return unless message.service_plan_guid
      return if service_instance.service_plan.plan_updateable?

      raise UnprocessableUpdate.new_from_details('ServicePlanNotUpdateable')
    end

    def raise_if_bind_inconsistency!(service_instance, message)
      return unless message.service_plan_guid
      return unless service_instance.service_bindings.any?
      return if ServicePlan.first(guid: message.service_plan_guid).bindable?

      raise UnprocessableUpdate.new_from_details(
        'ServicePlanInvalid',
        'cannot switch to non-bindable plan when service bindings exist'
      )
    end

    def raise_if_invalid_maintenance_info_change!(service_instance, message)
      return unless message.maintenance_info_version

      raise_if_concurrent_plan_update!(service_instance, message)
      raise_if_unsupported_by_current_plan!(service_instance, message)
      raise_if_version_mismatch!(service_instance, message)
    end

    def raise_if_concurrent_plan_update!(service_instance, message)
      return unless message.service_plan_guid
      return if message.service_plan_guid == service_instance.service_plan.guid

      raise UnprocessableUpdate.new_from_details('MaintenanceInfoNotUpdatableWhenChangingPlan')
    end

    def raise_if_unsupported_by_current_plan!(service_instance, message)
      return if service_instance.service_plan.maintenance_info

      raise UnprocessableUpdate.new_from_details('MaintenanceInfoNotSupported')
    end

    def raise_if_version_mismatch!(service_instance, message)
      is_plan_version = service_instance.service_plan.maintenance_info['version'] == message.maintenance_info_version
      is_current_version = service_instance.maintenance_info && message.maintenance_info_version == service_instance.maintenance_info['version']
      return if is_plan_version || is_current_version

      raise UnprocessableUpdate.new_from_details('MaintenanceInfoConflict')
    end
  end
end
