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

      if accepts_incomplete
        delete_job.perform
        return nil
      end

      delete_and_audit_job = build_audit_job(service_instance, delete_job)

      if async
        Jobs::Enqueuer.new(delete_and_audit_job, queue: 'cc-generic').enqueue
      else
        delete_and_audit_job.perform
        nil
      end
    end

    private

    def build_delete_job(service_instance, delete_action)
      Jobs::DeleteActionJob.new(VCAP::CloudController::ServiceInstance, service_instance.guid, delete_action)
    end

    def build_audit_job(service_instance, deletion_job)
      event_method = service_instance.managed_instance? ? :record_service_instance_event : :record_user_provided_service_instance_event
      Jobs::AuditEventJob.new(deletion_job, @services_event_repository, event_method, :delete, service_instance.class, service_instance.guid, {})
    end
  end
end
