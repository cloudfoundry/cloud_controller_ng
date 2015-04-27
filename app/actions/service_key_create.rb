require 'actions/synchronous_orphan_mitigate'

module VCAP::CloudController
  class ServiceKeyCreate
    def initialize(logger)
      @logger = logger
    end

    def create(service_instance, key_attrs, arbitrary_parameters)
      errors = []

      begin
        lock = BinderLock.new(service_instance)
        lock.lock!

        service_key = ServiceKey.new(key_attrs)

        attributes_to_update = service_key.client.create_service_key(service_key, arbitrary_parameters: arbitrary_parameters)

        begin
          service_key.set_all(attributes_to_update)
          service_key.save
        rescue
          orphan_mitigator = SynchronousOrphanMitigate.new(@logger)
          orphan_mitigator.attempt_delete_key(service_key)
          raise
        end

      rescue => e
        errors << e
      ensure
        lock.unlock_and_revert_operation! if lock.needs_unlock?
      end

      [service_key, errors]
    end
  end
end
