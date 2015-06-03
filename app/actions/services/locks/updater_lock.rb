require 'actions/services/locks/lock_check'

module VCAP::CloudController
  class UpdaterLock
    include VCAP::CloudController::LockCheck

    attr_reader :service_instance

    def initialize(service_instance, type='update')
      @service_instance = service_instance
      @type = type
    end

    def lock!
      ManagedServiceInstance.db.transaction do
        service_instance.lock!
        service_instance.last_operation.lock! if service_instance.last_operation

        raise_if_locked(service_instance)

        service_instance.save_with_new_operation(
          last_operation: {
            type: @type,
            state: 'in progress'
          }
        )
      end
    end

    def unlock_and_fail!
      ServiceInstanceOperation.db.transaction do
        service_instance.last_operation.update_attributes(
            type: @type,
            state: 'failed'
        )
      end
    end

    def synchronous_unlock!(operation_attrs)
      operation_attrs[:state] = 'succeeded'
      service_instance.update_last_operation(operation_attrs)
    end

    def enqueue_unlock!(job)
      enqueuer = Jobs::Enqueuer.new(job, queue: 'cc-generic')
      enqueuer.enqueue
    end
  end
end
