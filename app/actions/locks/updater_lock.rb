module VCAP::CloudController
  class UpdaterLock
    attr_reader :service_instance

    def initialize(service_instance, type='update')
      @service_instance = service_instance
      @type = type
    end

    def lock!
      ManagedServiceInstance.db.transaction do
        service_instance.lock!
        service_instance.last_operation.lock! if service_instance.last_operation

        if service_instance.operation_in_progress?
          raise Errors::ApiError.new_from_details('AsyncServiceInstanceOperationInProgress', service_instance.name)
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

    def synchronous_unlock!(attributes_to_update)
      service_instance.save_with_operation(attributes_to_update)
    end

    def enqueue_unlock!(attributes_to_update, job)
      service_instance.save_with_operation(attributes_to_update)
      enqueuer = Jobs::Enqueuer.new(job, queue: 'cc-generic')
      enqueuer.enqueue
    end
  end
end
