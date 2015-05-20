module VCAP::CloudController
  module LockCheck
    private

    def raise_if_locked(service_instance)
      if service_instance.operation_in_progress?
        raise VCAP::CloudController::Errors::ApiError.new_from_details('AsyncServiceInstanceOperationInProgress', service_instance.name)
      end
    end
  end
end
