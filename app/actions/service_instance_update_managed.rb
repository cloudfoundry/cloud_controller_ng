require 'jobs/v3/update_service_instance_job'
require 'repositories/service_event_repository'

module VCAP::CloudController
  class ServiceInstanceUpdateManaged
    class InvalidServiceInstance < StandardError
    end

    class NameTakenForServiceInstance < CloudController::Errors::ApiError
    end

    def initialize(service_event_repository)
      @service_event_repository = service_event_repository
    end

    def update(service_instance, message)
      raise_if_name_already_taken!(service_instance, message)

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

      service_name_changed || parameters_changed || service_plan_changed
    end

    def update_sync(service_instance, message)
      logger = Steno.logger('cc.action.service_instance_update')

      updates = {}
      updates[:name] = message.name if message.requested?(:name)
      updates[:tags] = message.tags if message.requested?(:tags)

      service_instance.db.transaction do
        service_instance.update(updates) if updates.any?
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

    def raise_if_name_already_taken!(service_instance, message)
      return unless message.requested?(:name)
      return unless service_instance.name != message.name
      return unless ServiceInstance.first(name: message.name, space: service_instance.space)

      raise NameTakenForServiceInstance.new_from_details('ServiceInstanceNameTaken', message.name)
    end
  end
end
