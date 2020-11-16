module VCAP::CloudController
  module V3
    class ServiceCredentialBindingKeyCreate
      class UnprocessableCreate < StandardError
      end

      def precursor(service_instance, volume_mount_services_enabled: false)
        if service_instance.managed_instance?
          service_not_bindable! unless service_instance.service_plan.bindable?
          service_not_available! unless service_instance.service_plan.active?
          volume_mount_not_enabled! if service_instance.volume_service? && !volume_mount_services_enabled
          operation_in_progress! if service_instance.operation_in_progress?
        else
          key_not_supported_for_user_provided_service!
        end
      end

      private

      def key_not_supported_for_user_provided_service!
        raise UnprocessableCreate.new("Service credential bindings of type 'key' are not supported for user-provided service instances.")
      end

      def operation_in_progress!
        raise UnprocessableCreate.new('There is an operation in progress for the service instance.')
      end

      def service_not_bindable!
        raise UnprocessableCreate.new('Service plan does not allow bindings.')
      end

      def service_not_available!
        raise UnprocessableCreate.new('Service plan is not available.')
      end

      def volume_mount_not_enabled!
        raise UnprocessableCreate.new('Support for volume mount services is disabled.')
      end
    end
  end
end
