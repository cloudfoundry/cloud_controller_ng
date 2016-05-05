require 'actions/services/synchronous_orphan_mitigate'
require 'actions/services/locks/lock_check'
require 'repositories/service_binding_event_repository'

module VCAP::CloudController
  class ServiceBindingCreate
    class ServiceInstanceNotBindable < StandardError; end
    class ServiceBrokerInvalidSyslogDrainUrl < StandardError; end
    class InvalidServiceBinding < StandardError; end
    class VolumeMountServiceDisabled < StandardError; end

    include VCAP::CloudController::LockCheck

    def initialize(user_guid, user_email)
      @user_guid = user_guid
      @user_email = user_email
    end

    def create(app_model, service_instance, message, volume_mount_services_enabled)
      raise ServiceInstanceNotBindable unless service_instance.bindable?
      service_binding = ServiceBindingModel.new(service_instance: service_instance,
                                                app: app_model,
                                                credentials: {},
                                                type: message.type)
      raise InvalidServiceBinding unless service_binding.valid?
      raise VolumeMountServiceDisabled if service_instance.volume_service? && !volume_mount_services_enabled

      raise_if_locked(service_binding.service_instance)

      raw_attrs = service_instance.client.bind(service_binding, message.parameters)
      attrs = raw_attrs.tap { |r| r.delete(:route_service_url) }

      service_binding.set_all(attrs)

      begin
        service_binding.save

        Repositories::ServiceBindingEventRepository.record_create(service_binding, @user_guid, @user_email, message.audit_hash)
      rescue => e
        logger.error "Failed to save state of create for service binding #{service_binding.guid} with exception: #{e}"
        mitigate_orphan(service_binding)
        raise e
      end

      service_binding
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
