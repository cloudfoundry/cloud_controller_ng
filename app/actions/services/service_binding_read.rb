module VCAP::CloudController
  class ServiceBindingRead
    class NotSupportedError < StandardError
    end

    def fetch_parameters(service_binding)
      unless service_binding.service_instance.managed_instance? && service_binding.service.bindings_retrievable
        raise NotSupportedError.new
      end

      client = VCAP::Services::ServiceClientProvider.provide(instance: service_binding.service_instance)
      response = client.fetch_service_binding(service_binding)
      response.fetch(:parameters, {})
    end
  end
end
