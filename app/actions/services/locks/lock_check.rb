module VCAP::CloudController
  module LockCheck
    class ServiceBindingLockedError < StandardError
      attr_reader :service_binding

      def initialize(service_binding, message: nil)
        super(message)
        @service_binding = service_binding
      end
    end

    private

    def raise_if_instance_locked(service_instance)
      if service_instance.operation_in_progress?
        raise CloudController::Errors::ApiError.new_from_details('AsyncServiceInstanceOperationInProgress', service_instance.name)
      end
    end

    def raise_if_binding_locked(service_binding)
      if service_binding.operation_in_progress?
        raise ServiceBindingLockedError.new(service_binding)
      end
    end
  end
end
