require 'actions/services/service_key_delete'
require 'actions/services/service_key_create'

module VCAP::CloudController
  class ServiceKeyManager
    class ServiceInstanceNotFound < StandardError; end
    class ServiceInstanceNotBindable < StandardError; end
    class ServiceInstanceUserProvided < StandardError; end

    def initialize(services_event_repository, access_validator, logger)
      @services_event_repository = services_event_repository
      @access_validator = access_validator
      @logger = logger
    end

    def create_service_key(request_attrs)
      service_instance = ServiceInstance.first(guid: request_attrs['service_instance_guid'])
      raise ServiceInstanceNotFound unless service_instance
      raise ServiceInstanceNotBindable unless service_instance.bindable?
      raise ServiceInstanceUserProvided if service_instance.user_provided_instance?

      validate_create_action(request_attrs)

      service_key, errors = ServiceKeyCreate.new(@logger).create(
        service_instance,
        request_attrs.except('parameters'),
        request_attrs['parameters']
      )

      raise errors.first if errors.present?

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

    def validate_create_action(request_attrs)
      service_key = ServiceKey.new(request_attrs.except('parameters'))
      @access_validator.validate_access(:create, service_key)
      raise Sequel::ValidationFailed.new(service_key) unless service_key.valid?
    end
  end
end
