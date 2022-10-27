require 'actions/services/locks/lock_check'

module VCAP::CloudController
  class DeleterLock
    include VCAP::CloudController::LockCheck

    attr_reader :service_instance

    def initialize(service_instance, type='delete')
      @service_instance = service_instance
      @type = type
      @needs_unlock = false
    end

    def lock!
      ManagedServiceInstance.db.transaction do
        service_instance.lock!

        try_to_cancel_last_operation!

        service_instance.save_with_new_operation({}, { type: @type, state: 'in progress' })

        @needs_unlock = true
      end
    end

    def unlock_and_fail!
      if @canceled_operation
        service_instance.update_last_operation(@canceled_operation.to_hash)
        @needs_unlock = false
        return
      end

      service_instance.save_and_update_operation(
        last_operation: {
          type: @type,
          state: 'failed'
        }
      )
      @needs_unlock = false
    end

    def unlock_and_destroy!
      # set state for code that use the service instance afterwards
      service_instance.last_operation.state = 'succeeded' if service_instance.last_operation
      service_instance.destroy
      @needs_unlock = false
    end

    def enqueue_and_unlock!(attributes_to_update, job)
      service_instance.save_and_update_operation(attributes_to_update)
      enqueuer = Jobs::Enqueuer.new(job, queue: Jobs::Queues.generic)
      enqueuer.enqueue
      @needs_unlock = false
    end

    def needs_unlock?
      @needs_unlock
    end

    private

    def try_to_cancel_last_operation!
      if cancellable_operation?(service_instance.last_operation)
        @canceled_operation = service_instance.last_operation
      else
        raise_if_instance_locked(service_instance)
      end
    end

    def cancellable_operation?(operation)
      operation && operation.state == 'in progress' && operation.type == 'create'
    end
  end
end
