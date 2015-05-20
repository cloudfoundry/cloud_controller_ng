require 'actions/services/service_binding_delete'
require 'actions/services/service_binding_create'

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

      validate_create_action(request_attrs)

      service_binding, errors = ServiceBindingCreate.new(@logger).bind(
          service_instance,
          request_attrs.except('parameters'),
          request_attrs['parameters']
      )

      if errors.present?
        raise errors.first
      end

      service_binding
    end

    def delete_service_instance_binding(service_binding, params)
      delete_action = ServiceBindingDelete.new
      deletion_job = Jobs::DeleteActionJob.new(ServiceBinding, service_binding.guid, delete_action)
      delete_and_audit_job = Jobs::AuditEventJob.new(
        deletion_job,
        @services_event_repository,
        :record_service_binding_event,
        :delete,
        service_binding.class,
        service_binding.guid
      )

      enqueue_deletion_job(delete_and_audit_job, params)
    end

    private

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

    def validate_create_action(request_attrs)
      service_binding = ServiceBinding.new(request_attrs.except('parameters'))
      @access_validator.validate_access(:create, service_binding)
      raise Sequel::ValidationFailed.new(service_binding) unless service_binding.valid?
    end
  end
end
