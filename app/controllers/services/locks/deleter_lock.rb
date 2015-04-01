module VCAP::CloudController
  class DeleterLock
    attr_reader :service_instance

    def initialize(service_instance, type='delete')
      @service_instance = service_instance
      @type = type
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
      end
    end

    def unlock_and_fail!
      service_instance.save_with_operation(
        last_operation: {
          type: @type,
          state: 'failed'
        }
      )
    end

    def unlock_and_delete!
      service_instance.last_operation.try(:destroy)
      service_instance.delete
    end

    def enqueue_unlock!(attributes_to_update, job)
      service_instance.save_with_operation(attributes_to_update)
      enqueuer = Jobs::Enqueuer.new(job, queue: 'cc-generic')
      enqueuer.enqueue
    end
  end
end
