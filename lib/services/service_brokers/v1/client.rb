module VCAP::Services
  class ServiceBrokers::V1::Client
    def initialize(attrs)
      @http_client = ServiceBrokers::V1::HttpClient.new(attrs)
    end

    def provision(instance, opts={})
      space = instance.space
      plan = instance.service_plan
      service = plan.service

      broker_plan_id = plan.unique_id
      name = instance.name

      response = @http_client.provision(
        broker_plan_id,
        name,
        {
          label: "#{service.label}-#{service.version}",
          email: VCAP::CloudController::SecurityContext.current_user_email,
          plan: plan.name,
          version: service.version,
          provider: service.provider,
          space_guid: space.guid,
          organization_guid: space.organization_guid
        }
      )

      {
        instance: {
          broker_provided_id: response.fetch('service_id'),
          gateway_data: response.fetch('configuration'),
          credentials: response.fetch('credentials'),
          dashboard_url: response.fetch('dashboard_url', nil),
        },
        last_operation: {
          type: 'create',
          state: 'succeeded',
          description: ''
        }
      }
    rescue HttpResponseError => e
      if e.source.is_a?(Hash) && e.source['code'] == 33106
        raise VCAP::Errors::ApiError.new_from_details('ServiceInstanceDuplicateNotAllowed')
      else
        raise
      end
    end

    def bind(binding, arbitrary_parameters: {})
      instance = binding.service_instance
      service = instance.service_plan.service

      broker_instance_id = instance.broker_provided_id
      app_instance_id = binding.app.guid
      label = "#{service.label}-#{service.version}"
      email = VCAP::CloudController::SecurityContext.current_user_email
      binding_options = binding.binding_options

      response = @http_client.bind(broker_instance_id, app_instance_id, label, email, binding_options)

      {
        broker_provided_id: response.fetch('service_id'),
        gateway_data: response.fetch('configuration'),
        credentials: response.fetch('credentials'),
        syslog_drain_url: (response['syslog_drain_url'].blank? ? instance.syslog_drain_url : response.fetch('syslog_drain_url'))
      }
    end

    def unbind(binding)
      instance = binding.service_instance

      broker_instance_id = instance.broker_provided_id
      broker_binding_id = binding.broker_provided_id
      binding_options = binding.binding_options

      @http_client.unbind(broker_instance_id, broker_binding_id, binding_options)
    end

    def deprovision(instance, opts={})
      broker_instance_id = instance.broker_provided_id

      @http_client.deprovision(broker_instance_id)
      {
        last_operation: {
          state: 'succeeded'
        }
      }
    rescue HttpResponseError => e
      raise VCAP::Errors::ApiError.new_from_details('ServiceInstanceDeprovisionFailed', e.message)
    end

    private

    def logger
      @logger ||= Steno.logger('cc.services.v1_client')
    end
  end
end
