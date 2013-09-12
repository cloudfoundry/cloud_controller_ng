module VCAP::CloudController
  class ServiceBroker::V2::Client
    def initialize(attrs)
      @http_client = ServiceBroker::V2::HttpClient.new(attrs)
    end

    def catalog
      @http_client.catalog
    end

    def provision(instance)
      response = @http_client.provision(instance.service_plan.service.broker_provided_id, instance.service_plan.broker_provided_id, instance.guid)

      instance.broker_provided_id = response['id']

      # DEPRECATED
      instance.credentials = {}
    end

    def bind(binding)
      response = @http_client.bind(binding.service_instance.broker_provided_id, binding.guid)

      binding.broker_provided_id = response['id']
      binding.credentials = response['credentials']
    end
  end
end
