module VCAP::CloudController
  class DeleterLock
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

        if service_instance.operation_in_progress?
          raise Errors::ApiError.new_from_details('ServiceInstanceOperationInProgress')
        end

        service_instance.save_with_operation(
          last_operation: {
            type: @type,
            state: 'in progress'
          }
        )
        @needs_unlock = true
      end
    end

    def unlock_and_fail!
      service_instance.save_with_operation(
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
      service_instance.save_with_operation(attributes_to_update)
      enqueuer = Jobs::Enqueuer.new(job, queue: 'cc-generic')
      enqueuer.enqueue
      @needs_unlock = false
    end

    def needs_unlock?
      @needs_unlock
    end
  end
end
