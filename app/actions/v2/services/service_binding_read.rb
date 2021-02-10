module VCAP::CloudController
  class ServiceBindingRead
    include VCAP::CloudController::LockCheck

    class NotSupportedError < StandardError
    end

    def fetch_parameters(service_binding)
      ensure_parameters_are_retrievable(service_binding)
      retrieve_parameters(service_binding)
    end

    private

    def ensure_parameters_are_retrievable(service_binding)
      unless binding_retrievable?(service_binding)
        raise NotSupportedError.new
      end

      raise_if_binding_locked(service_binding)
    end

    def retrieve_parameters(service_binding)
      client = VCAP::Services::ServiceClientProvider.provide(instance: service_binding.service_instance)
      response = client.fetch_service_binding(service_binding)
      response.fetch(:parameters, {})
    end

    def binding_retrievable?(service_binding)
      service_binding.service_instance.managed_instance? && service_binding.service.bindings_retrievable
    end
  end
end
