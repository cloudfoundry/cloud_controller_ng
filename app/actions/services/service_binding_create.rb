require 'actions/services/synchronous_orphan_mitigate'
require 'actions/services/locks/lock_check'

module VCAP::CloudController
  class ServiceBindingCreate
    include VCAP::CloudController::LockCheck

    def initialize(logger)
      @logger = logger
    end

    def bind(service_instance, binding_attrs, arbitrary_parameters)
      errors = []

      begin
        raise_if_locked(service_instance)

        service_binding = ServiceBinding.new(binding_attrs)
        attributes_to_update = service_binding.client.bind(service_binding, arbitrary_parameters: arbitrary_parameters)

        service_binding.set_all(attributes_to_update)

        begin
          service_binding.save
        rescue => e
          @logger.error "Failed to save state of create for service binding #{service_binding.guid} with exception: #{e}"
          orphan_mitigator = SynchronousOrphanMitigate.new(@logger)
          orphan_mitigator.attempt_unbind(service_binding)
          raise e
        end
      rescue => e
        errors << e
      end

      [service_binding, errors]
    end
  end
end
