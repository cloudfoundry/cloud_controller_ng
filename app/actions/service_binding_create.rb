require 'actions/synchronous_orphan_mitigate'

module VCAP::CloudController
  class ServiceBindingCreate
    def initialize(logger)
      @logger = logger
    end

    def bind(service_instance, binding_attrs, arbitrary_parameters)
      errors = []

      begin
        lock = BinderLock.new(service_instance)
        lock.lock!

        service_binding = ServiceBinding.new(binding_attrs)
        attributes_to_update = service_binding.client.bind(service_binding, arbitrary_parameters: arbitrary_parameters)

        begin
          service_binding.set_all(attributes_to_update)
          service_binding.save
        rescue => e
          @logger.error "Failed to save state of create for service binding #{service_binding.guid} with exception: #{e}"
          orphan_mitigator = SynchronousOrphanMitigate.new(@logger)
          orphan_mitigator.attempt_unbind(service_binding)
          raise e
        end

      rescue => e
        errors << e
      ensure
        lock.unlock_and_revert_operation! if lock.needs_unlock?
      end

      [service_binding, errors]
    end
  end
end
