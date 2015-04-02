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

      delete_and_audit_job = build_delete_job(service_instance)
      begin
        if accepts_incomplete?(params)
          perform_accepts_incomplete_delete(service_instance)
        elsif async?(params)
          enqueued_job = Jobs::Enqueuer.new(delete_and_audit_job, queue: 'cc-generic').enqueue
          [nil, enqueued_job]
        else
          delete_and_audit_job.perform
          nil
        end
      rescue
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
      deletion_job = Jobs::DeleteActionJob.new(VCAP::CloudController::ServiceInstance, service_instance.guid, ServiceInstanceDelete.new)
      event_method = service_instance.managed_instance? ? :record_service_instance_event : :record_user_provided_service_instance_event
      Jobs::AuditEventJob.new(deletion_job, @services_event_repository, event_method, :delete, service_instance, {})
    end

    def perform_accepts_incomplete_delete(service_instance)
      errs = ServiceInstanceDelete.new(accepts_incomplete: true, event_repository_opts: event_repository_opts).delete([service_instance])
      raise errs.first unless errs.empty?
      begin
        service_instance.reload
        [service_instance, nil]
      rescue
        nil
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
