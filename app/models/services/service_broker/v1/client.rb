module VCAP::CloudController
  class ServiceBroker::V1::Client
    def initialize(attrs)
      @http_client = ManagedServiceInstance.gateway_client_class.new(
        attrs.fetch(:url),
        attrs.fetch(:auth_token),
        attrs.fetch(:timeout),
        VCAP::Request.current_id
      )
    end

    def provision(instance)
      space = instance.space
      plan = instance.service_plan
      service = plan.service

      response = @http_client.provision(
        label: "#{service.label}-#{service.version}",
        name: instance.name,
        email: VCAP::CloudController::SecurityContext.current_user_email,
        plan: plan.name,
        version: service.version,
        provider: service.provider,
        space_guid: space.guid,
        organization_guid: space.organization_guid,
        unique_id: plan.unique_id,

        # DEPRECATED
        plan_option: {}
      )

      instance.broker_provided_id = response.service_id
      instance.gateway_data = response.configuration
      instance.credentials = response.credentials
      instance.dashboard_url = response.dashboard_url
    rescue VCAP::Services::Api::ServiceGatewayClient::ErrorResponse => e
      case e.error.code
      when 33106
        raise VCAP::Errors::ServiceInstanceDuplicateNotAllowed
      else
        raise
      end
    end

    def bind(binding)
      instance = binding.service_instance
      service = instance.service_plan.service

      response = @http_client.bind(
        service_id: instance.broker_provided_id,
        label: "#{service.label}-#{service.version}",
        email: VCAP::CloudController::SecurityContext.current_user_email,
        binding_options: binding.binding_options,
      )

      binding.broker_provided_id = response.service_id
      binding.gateway_data = response.configuration
      binding.credentials = response.credentials
      binding.syslog_drain_url = response.syslog_drain_url

      unless valid_logging_service(response.syslog_drain_url, service.requires)
        raise VCAP::Errors::BindingUnadvertisedLoggingServiceNotAllowed
      end
    end

    def unbind(binding)
      instance = binding.service_instance

      @http_client.unbind(
        service_id: instance.broker_provided_id,
        handle_id: binding.broker_provided_id,
        binding_options: binding.binding_options
      )
    rescue VCAP::Services::Api::ServiceGatewayClient::NotFoundResponse
      logger.info "Ignored 404 from broker during unbind of binding #{binding.guid} (broker_provided_id: #{binding.broker_provided_id})"
    end

    def deprovision(instance)
      @http_client.unprovision(
        service_id: instance.broker_provided_id
      )
    rescue VCAP::Services::Api::ServiceGatewayClient::NotFoundResponse
      logger.info "Ignored 404 from broker during deprovision of instance #{instance.guid} (broker_provided_id: #{instance.broker_provided_id})"
    end

    private
    def logger
      @logger ||= Steno.logger("cc.services.v1_client")
    end

    def valid_logging_service(syslog_drain_url, service_requires)
      (syslog_drain_url == "") || service_requires.include?("syslog_drain")
    end
  end
end
