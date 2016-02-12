require 'actions/services/synchronous_orphan_mitigate'
require 'actions/services/locks/lock_check'

module VCAP::CloudController
  class ServiceBindingCreate
    class ServiceInstanceNotBindable < StandardError; end
    class ServiceBrokerInvalidSyslogDrainUrl < StandardError; end
    class InvalidServiceBinding < StandardError; end

    include VCAP::CloudController::LockCheck

    def create(app_model, service_instance, type, arbitrary_parameters)
      raise ServiceInstanceNotBindable unless service_instance.bindable?
      service_binding = ServiceBindingModel.new(service_instance: service_instance,
                                                app: app_model,
                                                credentials: {},
                                                type: type)
      raise InvalidServiceBinding unless service_binding.valid?

      raise_if_locked(service_binding.service_instance)

      raw_attrs = service_instance.client.bind(service_binding, arbitrary_parameters)
      attrs = raw_attrs.tap { |r| r.delete(:route_service_url) }

      service_binding.set_all(attrs)

      begin
        service_binding.save

        service_event_repository.record_service_binding_event(:create, service_binding)
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

    def service_event_repository
      CloudController::DependencyLocator.instance.services_event_repository
    end
  end
end
