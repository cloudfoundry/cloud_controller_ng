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
        service_instance.last_operation.lock! if service_instance.last_operation

        raise_if_locked(service_instance)

        service_instance.save_with_new_operation(
          last_operation: {
            type: @type,
            state: 'in progress'
          }
        )
        @needs_unlock = true
      end
    end

    def unlock_and_fail!
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

    def enqueue_unlock!(attributes_to_update, job)
      service_instance.save_and_update_operation(attributes_to_update)
      enqueuer = Jobs::Enqueuer.new(job, queue: 'cc-generic')
      enqueuer.enqueue
      @needs_unlock = false
    end

    def needs_unlock?
      @needs_unlock
    end
  end
end
