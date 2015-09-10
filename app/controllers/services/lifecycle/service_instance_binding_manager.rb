require 'actions/services/service_binding_delete'
require 'models/services/route_binding'

module VCAP::CloudController
  class ServiceInstanceBindingManager
    class ServiceInstanceNotFound < StandardError; end
    class ServiceInstanceNotBindable < StandardError; end
    class AppNotFound < StandardError; end

    include VCAP::CloudController::LockCheck

    def initialize(services_event_repository, access_validator, logger)
      @services_event_repository = services_event_repository
      @access_validator = access_validator
      @logger = logger
    end

    def create_route_service_instance_binding(route, instance)
      raise ServiceInstanceNotBindable unless instance.bindable?

      binding = RouteBinding.new(route, instance)
      @access_validator.validate_access(:create, binding)

      route.service_instance = instance
      raise Sequel::ValidationFailed.new(route) unless route.valid?

      bind(binding, {})

      begin
        route.save
      rescue => e
        @logger.error "Failed to save binding for route: #{route.guid} and service instance: #{instance.guid} with exception: #{e}"
        mitigate_orphan(binding)
        raise e
      end
    end

    def create_app_service_instance_binding(service_instance_guid, app_guid, binding_attrs, arbitrary_parameters)
      service_instance = ServiceInstance.first(guid: service_instance_guid)
      raise ServiceInstanceNotFound unless service_instance
      raise ServiceInstanceNotBindable unless service_instance.bindable?
      raise AppNotFound unless App.first(guid: app_guid)

      validate_app_create_action(binding_attrs)

      service_binding = ServiceBinding.new(binding_attrs)

      attributes_to_update = bind(service_binding, arbitrary_parameters)

      service_binding.set_all(attributes_to_update)

      begin
        service_binding.save
      rescue => e
        @logger.error "Failed to save state of create for service binding #{service_binding.guid} with exception: #{e}"
        mitigate_orphan(service_binding)
        raise e
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

    def bind(binding, arbitrary_parameters)
      raise_if_locked(binding.service_instance)
      binding.service_instance.client.bind(binding, arbitrary_parameters: arbitrary_parameters)
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

    def validate_app_create_action(binding_attrs)
      service_binding = ServiceBinding.new(binding_attrs)
      @access_validator.validate_access(:create, service_binding)
      raise Sequel::ValidationFailed.new(service_binding) unless service_binding.valid?
    end

    def mitigate_orphan(binding)
      orphan_mitigator = SynchronousOrphanMitigate.new(@logger)
      orphan_mitigator.attempt_unbind(binding)
    end
  end
end
