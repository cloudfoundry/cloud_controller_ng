module VCAP::CloudController
  class ServiceBroker::V2::Client
    def initialize(attrs)
      @http_client = ServiceBroker::V2::HttpClient.new(attrs)
    end

    def catalog
      @http_client.catalog
    end

    def provision(instance)
      response = @http_client.provision(
        instance_id: instance.guid,
        service_id: instance.service.broker_provided_id,
        plan_id: instance.service_plan.broker_provided_id,
        org_guid: instance.organization.guid,
        space_guid: instance.space.guid,
      )

      instance.dashboard_url = response['dashboard_url']

      # DEPRECATED, but needed because of not null constraint
      instance.credentials = {}
    end

    def bind(binding)
      response = @http_client.bind(
        binding_id: binding.guid,
        instance_id: binding.service_instance.guid,
        service_id: binding.service.broker_provided_id,
        plan_id: binding.service_plan.broker_provided_id
      )

      binding.credentials = response['credentials']
    end

    def unbind(binding)
      @http_client.unbind(
        binding_id: binding.guid,
        instance_id: binding.service_instance.guid,
        service_id: binding.service.broker_provided_id,
        plan_id: binding.service_plan.broker_provided_id,
      )
    end

    def deprovision(instance)
      @http_client.deprovision(instance.guid)
    end
  end
end
