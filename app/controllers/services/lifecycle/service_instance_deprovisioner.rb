module VCAP::CloudController
  class ServiceInstanceDeprovisioner
    def initialize(services_event_repository, access_validator, logger)
      @services_event_repository = services_event_repository
      @access_validator = access_validator
      @logger = logger
    end

    def deprovision_service_instance(service_instance, params)
      @access_validator.validate_access(:delete, service_instance)

      return perform_delete(service_instance, params) unless service_instance.managed_instance?

      service_instance.lock_by_failing_other_operations('delete') do
        if accepts_incomplete?(params) && service_instance.managed_instance?
          perform_accepts_incomplete_delete(service_instance)
        else
          perform_delete(service_instance, params)
        end
      end
    end

    private

    def accepts_incomplete?(params)
      params['accepts_incomplete'] == 'true'
    end

    def async?(params)
      params['async'] == 'true'
    end

    def enqueue_deletion_job(deletion_job, params)
      if async?(params)
        job = Jobs::Enqueuer.new(deletion_job, queue: 'cc-generic').enqueue
        [nil, job]
      else
        deletion_job.perform
        nil
      end
    end

    def perform_delete(service_instance, params)
      deletion_job = Jobs::Services::ServiceInstanceDeletion.new(service_instance.guid)
      event_method = service_instance.type == 'managed_service_instance' ?  :record_service_instance_event : :record_user_provided_service_instance_event
      delete_and_audit_job = Jobs::AuditEventJob.new(deletion_job, @services_event_repository, event_method, :delete, service_instance, {})

      enqueue_deletion_job(delete_and_audit_job, params)
    end

    def perform_accepts_incomplete_delete(service_instance)
      attributes_to_update, err = service_instance.client.deprovision(
        service_instance,
        event_repository_opts: {
          user: SecurityContext.current_user,
          user_email: SecurityContext.current_user_email
        },
        request_attrs: {}
      )
      raise err if err

      service_instance.update_from_broker_response(attributes_to_update)
      if service_instance.last_operation.state == 'succeeded'
        service_instance.last_operation.try(:destroy)
        # do not destroy, we already deprovisioned from the broker
        service_instance.delete
      end

      attributes_to_update ||= {}
      last_operation_hash = attributes_to_update[:last_operation] || {}
      if last_operation_hash[:state] == 'in progress'
        [service_instance, nil]
      end
    end
  end
end
