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
      service_instance.save_and_update_operation(
        last_operation: {
          type: @type,
          state: 'failed'
        }
      )
    end

    def synchronous_unlock!(attributes_to_update)
      service_instance.save_and_update_operation(attributes_to_update)
    end

    def enqueue_unlock!(attributes_to_update, job)
      service_instance.save_and_update_operation(attributes_to_update)
      enqueuer = Jobs::Enqueuer.new(job, queue: 'cc-generic')
      enqueuer.enqueue
    end
  end
end
