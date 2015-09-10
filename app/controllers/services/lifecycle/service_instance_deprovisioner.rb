module VCAP::CloudController
  class ServiceInstanceDeprovisioner
    def initialize(services_event_repository, access_validator, logger)
      @services_event_repository = services_event_repository
      @access_validator = access_validator
      @logger = logger
    end

    def deprovision_service_instance(service_instance, accepts_incomplete, async)
      delete_action = ServiceInstanceDelete.new(
        accepts_incomplete: accepts_incomplete,
        event_repository: @services_event_repository
      )

      delete_job = build_delete_job(service_instance, delete_action)

      enqueued_job = nil

      if async && !accepts_incomplete
        enqueued_job = Jobs::Enqueuer.new(build_audit_job(service_instance, delete_job), queue: 'cc-generic').enqueue
      else
        delete_job.perform
        log_audit_event(service_instance) unless service_instance.exists?
      end

      enqueued_job
    end

    private

    def build_delete_job(service_instance, delete_action)
      Jobs::DeleteActionJob.new(VCAP::CloudController::ServiceInstance, service_instance.guid, delete_action)
    end

    def build_audit_job(service_instance, deletion_job)
      event_method = service_instance.managed_instance? ? :record_service_instance_event : :record_user_provided_service_instance_event
      Jobs::AuditEventJob.new(deletion_job, @services_event_repository, event_method, :delete, service_instance.class, service_instance.guid, {})
    end

    def log_audit_event(service_instance)
      event_method = service_instance.managed_instance? ? :record_service_instance_event : :record_user_provided_service_instance_event
      @services_event_repository.send(event_method, :delete, service_instance, {})
    end
  end
end
