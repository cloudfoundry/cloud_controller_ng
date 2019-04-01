require 'repositories/service_instance_share_event_repository'

module VCAP::CloudController
  class ServiceInstanceRead
    include VCAP::CloudController::LockCheck
    class NotSupportedError < ::StandardError
    end

    def fetch_parameters(service_instance)
      resp = fetch_from_broker(service_instance)
      resp.fetch(:parameters, {})
    end

    private

    def fetch_from_broker(service_instance)
      if service_instance.user_provided_instance? || !service_instance.service.instances_retrievable
        raise NotSupportedError.new
      end

      raise_if_instance_locked(service_instance)

      client = VCAP::Services::ServiceClientProvider.provide(instance: service_instance)
      client.fetch_service_instance(service_instance)
    end
  end
end
