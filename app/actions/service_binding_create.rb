require 'actions/synchronous_orphan_mitigate'

module VCAP::CloudController
  class ServiceBindingCreate
    def initialize(logger)
      @logger = logger
    end

    def bind(service_instance, binding_attrs, request_params)
      errors = []

      begin
        lock = BinderLock.new(service_instance)
        lock.lock!

        service_binding = ServiceBinding.new(binding_attrs)
        attributes_to_update = service_binding.client.bind(service_binding, request_params: request_params)

        begin
          service_binding.set_all(attributes_to_update)
          service_binding.save
        rescue
          orphan_mitigator = SynchronousOrphanMitigate.new(@logger)
          orphan_mitigator.attempt_unbind(service_binding)
          raise
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
