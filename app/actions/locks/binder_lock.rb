module VCAP::CloudController
  class BinderLock
    attr_reader :service_instance

    def initialize(service_instance, type='update')
      @service_instance = service_instance
      @type = type
      @needs_unlock = false
      @cached_operation = nil
    end

    def lock!
      ManagedServiceInstance.db.transaction do
        service_instance.lock!
        service_instance.last_operation.lock! if service_instance.last_operation

        if service_instance.operation_in_progress?
          raise Errors::ApiError.new_from_details('ServiceInstanceOperationInProgress')
        end

        @cached_operation = service_instance.last_operation

        service_instance.save_with_operation(
          last_operation: {
            type: @type,
            state: 'in progress'
          }
        )
        @needs_unlock = true
      end
    end

    def unlock_and_revert_operation!
      service_instance.service_instance_operation = @cached_operation
      @needs_unlock = false
    end

    def needs_unlock?
      @needs_unlock
    end
  end
end
