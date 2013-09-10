module VCAP::CloudController
  class ServiceProvisioner
    ProvisionResponse = Struct.new(:gateway_name, :gateway_data, :credentials, :dashboard_url)

    def initialize(service_instance, opts={})
      if service_instance.service.v2?
        @provisioner = V2ServiceProvisioner.new(service_instance, opts)
      else
        @provisioner = V1ServiceProvisioner.new(service_instance)
      end
    end

    def provision
      @provisioner.provision
    end
  end

  class V1ServiceProvisioner
    def initialize(service_instance)
      @service_instance = service_instance
    end

    def provision
      logger.debug "provisioning service for instance #{service_instance.guid}"

      service_plan = service_instance.service_plan
      service = service_instance.service
      space = service_instance.space

      gateway_response = service_gateway_client(service_plan).provision(
        # TODO: we shouldn't still be using this compound label
        :label => "#{service.label}-#{service.version}",
        :name  => service_instance.name,
        :email => VCAP::CloudController::SecurityContext.current_user_email,
        :plan  => service_plan.name,
        :plan_option => {}, # TODO: remove this
        :version => service.version,
        :provider => service.provider,
        :space_guid => space.guid,
        :organization_guid => space.organization_guid,
        :unique_id => service_plan.unique_id,
      )

      logger.debug "provision response for instance #{service_instance.guid} #{gateway_response.inspect}"

      ServiceProvisioner::ProvisionResponse.new(
        gateway_response.service_id,
        gateway_response.configuration,
        gateway_response.credentials,
        gateway_response.dashboard_url
      )

    rescue VCAP::Services::Api::ServiceGatewayClient::ErrorResponse => e
      if e.error.code == 33106
        raise VCAP::Errors::ServiceInstanceDuplicateNotAllowed
      else
        raise
      end
    end

    private

    attr_reader :service_instance

    def logger
      @logger ||= Steno.logger("cc.models.service_provisioner")
    end

    def service_gateway_client(service_plan)
      @client ||= begin

        raise ServiceInstance::InvalidServiceBinding.new("no service_auth_token") unless service_plan.service.service_auth_token

        ManagedServiceInstance.gateway_client_class.new(
          service_plan.service.url,
          service_plan.service.service_auth_token.token,
          service_plan.service.timeout,
          VCAP::Request.current_id,
        )
      end
    end
  end

  class V2ServiceProvisioner
    def initialize(service_instance, opts={})
      @service_instance = service_instance
      @broker_client = opts.fetch(:broker_client) do
        service_instance.service_plan.service.service_broker.client
      end
    end

    def provision
      provision_response = broker_client.provision(
        service_instance.service.broker_provided_id,
        service_instance.service_plan.broker_provided_id,
        service_instance.guid
      )
      ServiceProvisioner::ProvisionResponse.new(
        provision_response[:id],
        nil,
        {},
        nil
      )
    end

    private

    attr_reader :service_instance, :broker_client
  end
end
