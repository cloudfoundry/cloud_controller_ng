require 'actions/services/locks/lock_check'

module VCAP::CloudController
  class ServiceKeyDelete
    include VCAP::CloudController::LockCheck

    def delete(service_binding_dataset)
      service_binding_dataset.each_with_object([]) do |service_binding, errs|
        errs.concat delete_service_binding(service_binding)
      end
    end

    private

    def delete_service_binding(service_binding)
      errors = []
      service_instance = service_binding.service_instance
      client = VCAP::Services::ServiceClientProvider.provide(instance: service_instance)

      begin
        raise_if_locked(service_instance)

        client.unbind(service_binding)
        service_binding.destroy
      rescue => e
        errors << e
      end

      errors
    end
  end
end
