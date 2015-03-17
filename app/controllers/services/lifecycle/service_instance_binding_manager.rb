require 'actions/service_binding_delete'

module VCAP::CloudController
  class ServiceInstanceBindingManager
    class ServiceInstanceNotFound < StandardError; end
    class ServiceInstanceNotBindable < StandardError; end
    class AppNotFound < StandardError; end

    def initialize(services_event_repository, access_validator, logger)
      @services_event_repository = services_event_repository
      @access_validator = access_validator
      @logger = logger
    end

    def create_service_instance_binding(request_attrs)
      service_instance = ServiceInstance.first(guid: request_attrs['service_instance_guid'])
      raise ServiceInstanceNotFound unless service_instance
      raise ServiceInstanceNotBindable unless service_instance.bindable?
      raise AppNotFound unless App.first(guid: request_attrs['app_guid'])

      service_binding = ServiceBinding.new(request_attrs)
      @access_validator.validate_access(:create, service_binding)
      raise Sequel::ValidationFailed.new(service_binding) unless service_binding.valid?

      lock_service_instance_by_blocking(service_instance) do
        attributes_to_update = service_binding.client.bind(service_binding)
        begin
          service_binding.set_all(attributes_to_update)
          service_binding.save
        rescue
          safe_unbind_instance(service_binding)
          raise
        end
      end

      service_binding
    end

    def delete_service_instance_binding(service_binding, params)
      service_instance = ServiceInstance.first(guid: service_binding.service_instance_guid)

      lock_service_instance_by_blocking(service_instance) do
        delete_action = ServiceBindingDelete.new
        deletion_job = Jobs::DeleteActionJob.new(ServiceBinding, service_binding.guid, delete_action)
        delete_and_audit_job = Jobs::AuditEventJob.new(deletion_job, @services_event_repository, :record_service_binding_event, :delete, service_binding)

        enqueue_deletion_job(delete_and_audit_job, params)
      end
    end

    private

    def safe_unbind_instance(service_binding)
      service_binding.client.unbind(service_binding)
    rescue => e
      @logger.error "Unable to unbind #{service_binding}: #{e}"
    end

    def async?(params)
      params['async'] == 'true'
    end

    def enqueue_deletion_job(deletion_job, params)
      if async?(params)
        Jobs::Enqueuer.new(deletion_job, queue: 'cc-generic').enqueue
      else
        deletion_job.perform
        nil
      end
    end

    def lock_service_instance_by_blocking(service_instance, &block)
      return block.call unless service_instance.managed_instance?

      original_attributes = service_instance.last_operation.try(:to_hash)
      begin
        service_instance.lock_by_failing_other_operations('update') do
          block.call
        end
      ensure
        if original_attributes
          service_instance.last_operation.set_all(original_attributes)
          service_instance.last_operation.save
        else
          service_instance.service_instance_operation.destroy
          service_instance.save
        end
      end
    end
  end
end
