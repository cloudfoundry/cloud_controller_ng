module VCAP::CloudController
  class ServiceInstanceDeprovisioner
    def initialize(services_event_repository, access_validator, logger)
      @services_event_repository = services_event_repository
      @access_validator = access_validator
      @logger = logger
    end

    def deprovision_service_instance(service_instance, params)
      @access_validator.validate_access(:delete, service_instance)

      delete_action = ServiceInstanceDelete.new(
        accepts_incomplete: accepts_incomplete?(params),
        event_repository_opts: event_repository_opts
      )

      delete_job = build_delete_job(service_instance, delete_action)

      if accepts_incomplete?(params)
        delete_job.perform
        if service_instance.exists?
          return instance_remains_response(service_instance)
        else
          return delete_complete_response
        end
      end

      delete_and_audit_job = build_audit_job(service_instance, delete_job)

      if async?(params)
        enqueued_job = Jobs::Enqueuer.new(delete_and_audit_job, queue: 'cc-generic').enqueue
        enqueued_delete_response(enqueued_job)
      else
        delete_and_audit_job.perform
        delete_complete_response
      end
    end

    private

    def accepts_incomplete?(params)
      params['accepts_incomplete'] == 'true'
    end

    def async?(params)
      params['async'] == 'true'
    end

    def instance_remains_response(service_instance)
      [service_instance, nil]
    end

    def delete_complete_response
      nil
    end

    def enqueued_delete_response(enqueued_job)
      [nil, enqueued_job]
    end

    def build_delete_job(service_instance, delete_action)
      Jobs::DeleteActionJob.new(VCAP::CloudController::ServiceInstance, service_instance.guid, delete_action)
    end

    def build_audit_job(service_instance, deletion_job)
      event_method = service_instance.managed_instance? ? :record_service_instance_event : :record_user_provided_service_instance_event
      Jobs::AuditEventJob.new(deletion_job, @services_event_repository, event_method, :delete, service_instance, {})
    end

    def event_repository_opts
      {
        user: SecurityContext.current_user,
        user_email: SecurityContext.current_user_email
      }
    end
  end
end
