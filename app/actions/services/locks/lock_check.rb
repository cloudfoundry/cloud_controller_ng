module VCAP::CloudController
  module LockCheck
    private

    def raise_if_instance_locked(service_instance)
      if service_instance.operation_in_progress?
        raise CloudController::Errors::ApiError.new_from_details('AsyncServiceInstanceOperationInProgress', service_instance.name)
      end
    end

    def raise_if_binding_locked(service_binding)
      if service_binding.operation_in_progress?
        raise CloudController::Errors::ApiError.new_from_details('AsyncServiceBindingOperationInProgress', service_binding.name)
      end
    end
  end
end
