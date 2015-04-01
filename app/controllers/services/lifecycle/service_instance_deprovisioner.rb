require 'controllers/services/locks/deleter_lock'

module VCAP::CloudController
  class ServiceInstanceDeprovisioner
    def initialize(services_event_repository, access_validator, logger)
      @services_event_repository = services_event_repository
      @access_validator = access_validator
      @logger = logger
    end

    def deprovision_service_instance(service_instance, params)
      @access_validator.validate_access(:delete, service_instance)

      if service_instance.user_provided_instance?
        delete_and_audit_job = build_delete_job(service_instance)

        if async?(params)
          enqueued_job = Jobs::Enqueuer.new(delete_and_audit_job, queue: 'cc-generic').enqueue
          return [nil, enqueued_job]
        else
          delete_and_audit_job.perform
          return nil
        end
      end

      lock = DeleterLock.new(service_instance)
      lock.lock!

      delete_and_audit_job = build_delete_job(service_instance)
      begin
        if accepts_incomplete?(params)
          perform_accepts_incomplete_delete(service_instance, lock)
        elsif async?(params)
          enqueued_job = lock.enqueue_unlock!({}, delete_and_audit_job)
          [nil, enqueued_job]
        else
          delete_and_audit_job.perform
          nil
        end
      rescue
        lock.unlock_and_fail!
        raise
      end
    end

    private

    def accepts_incomplete?(params)
      params['accepts_incomplete'] == 'true'
    end

    def async?(params)
      params['async'] == 'true'
    end

    def build_delete_job(service_instance)
      deletion_job = Jobs::Services::ServiceInstanceDeletion.new(service_instance.guid)
      event_method = service_instance.managed_instance? ? :record_service_instance_event : :record_user_provided_service_instance_event
      Jobs::AuditEventJob.new(deletion_job, @services_event_repository, event_method, :delete, service_instance, {})
    end

    def perform_accepts_incomplete_delete(service_instance, lock)
      attributes_to_update, poll_interval_seconds = service_instance.client.deprovision(
        service_instance,
        accepts_incomplete: true
      )

      service_instance.update_from_broker_response(attributes_to_update)
      if service_instance.last_operation.state == 'succeeded'
        lock.unlock_and_delete!
        return
      end

      attributes_to_update ||= {}
      if service_instance.operation_in_progress?
        job = VCAP::CloudController::Jobs::Services::ServiceInstanceStateFetch.new(
          'service-instance-state-fetch',
          service_instance.client.attrs,
          service_instance.guid,
          event_repository_opts,
          {},
          poll_interval_seconds,
        )

        lock.enqueue_unlock!(attributes_to_update, job)
        [service_instance, nil]
      end
    end

    def event_repository_opts
      {
        user: SecurityContext.current_user,
        user_email: SecurityContext.current_user_email
      }
    end
  end
end
