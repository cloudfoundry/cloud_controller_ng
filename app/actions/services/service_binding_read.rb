module VCAP::CloudController
  class ServiceBindingRead
    include VCAP::CloudController::LockCheck
    class NotSupportedError < StandardError
    end

    def fetch_parameters(service_binding)
      unless service_binding.service_instance.managed_instance? && service_binding.service.bindings_retrievable
        raise NotSupportedError.new
      end

      raise_if_binding_locked(service_binding)

      client = VCAP::Services::ServiceClientProvider.provide(instance: service_binding.service_instance)
      response = client.fetch_service_binding(service_binding)
      response.fetch(:parameters, {})
    end
  end
end
