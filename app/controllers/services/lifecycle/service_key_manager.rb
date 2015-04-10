require 'actions/service_key_delete'

module VCAP::CloudController
  class ServiceKeyManager
    class ServiceInstanceNotFound < StandardError; end
    class ServiceInstanceNotBindable < StandardError; end

    def initialize(services_event_repository, access_validator, logger)
      @services_event_repository = services_event_repository
      @access_validator = access_validator
      @logger = logger
    end

    def create_service_key(request_attrs)
      service_instance = ServiceInstance.first(guid: request_attrs['service_instance_guid'])
      raise ServiceInstanceNotFound unless service_instance
      raise ServiceInstanceNotBindable unless service_instance.bindable?

      service_key = ServiceKey.new(request_attrs)
      @access_validator.validate_access(:create, service_key)
      raise Sequel::ValidationFailed.new(service_key) unless service_key.valid?

      lock_service_instance_by_blocking(service_instance) do
        attributes_to_update = service_key.client.bind(service_key)
        begin
          service_key.set_all(attributes_to_update)
          service_key.save
        rescue
          safe_unbind_instance(service_key)
          raise
        end
      end

      service_key
    end

    def delete_service_key(service_key)
      delete_action = ServiceKeyDelete.new
      deletion_job = Jobs::DeleteActionJob.new(ServiceKey, service_key.guid, delete_action)
      delete_and_audit_job = Jobs::AuditEventJob.new(
          deletion_job,
          @services_event_repository,
          :record_service_key_event,
          :delete,
          service_key.class,
          service_key.guid
      )

      delete_and_audit_job.perform
    end

    private

    def safe_unbind_instance(service_key)
      service_key.client.unbind(service_key)
    rescue => e
      @logger.error "Unable to unbind #{service_key}: #{e}"
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
