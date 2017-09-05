require 'actions/services/synchronous_orphan_mitigate'
require 'actions/services/locks/lock_check'
require 'repositories/service_binding_event_repository'

module VCAP::CloudController
  class ServiceBindingCreate
    class InvalidServiceBinding < StandardError; end
    class ServiceInstanceNotBindable < InvalidServiceBinding; end
    class ServiceBrokerInvalidSyslogDrainUrl < InvalidServiceBinding; end
    class VolumeMountServiceDisabled < InvalidServiceBinding; end
    class SpaceMismatch < InvalidServiceBinding; end

    include VCAP::CloudController::LockCheck

    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def create(app, service_instance, message, volume_mount_services_enabled)
      raise ServiceInstanceNotBindable unless service_instance.bindable?
      raise VolumeMountServiceDisabled if service_instance.volume_service? && !volume_mount_services_enabled
      raise SpaceMismatch if service_instance.space_guid != app.space_guid
      raise_if_locked(service_instance)

      binding = ServiceBinding.new(
        service_instance: service_instance,
        app:              app,
        credentials:      {},
        type:             message.type
      )
      raise InvalidServiceBinding unless binding.valid?

      binding_result = request_binding_from_broker(service_instance, binding, message.parameters)

      binding.set(binding_result)

      begin
        binding.save

        Repositories::ServiceBindingEventRepository.record_create(binding, @user_audit_info, message.audit_hash)
      rescue => e
        logger.error "Failed to save state of create for service binding #{binding.guid} with exception: #{e}"
        mitigate_orphan(binding)
        raise e
      end

      binding
    end

    private

    def request_binding_from_broker(instance, service_binding, parameters)
      client = VCAP::Services::ServiceClientProvider.provide(instance: instance)
      client.bind(service_binding, parameters).tap do |response|
        response.delete(:route_service_url)
      end
    end

    def mitigate_orphan(binding)
      orphan_mitigator = SynchronousOrphanMitigate.new(logger)
      orphan_mitigator.attempt_unbind(binding)
    end

    def logger
      @logger ||= Steno.logger('cc.action.service_binding_create')
    end
  end
end
