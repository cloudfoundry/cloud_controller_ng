module VCAP::Services::ServiceBrokers::V2
  class Client
    CATALOG_PATH = '/v2/catalog'.freeze

    def initialize(attrs)
      http_client_attrs = attrs.select { |key, _| [:url, :auth_username, :auth_password].include?(key) }
      @http_client = VCAP::Services::ServiceBrokers::V2::HttpClient.new(http_client_attrs)
      @response_parser = VCAP::Services::ServiceBrokers::V2::ResponseParser.new(@http_client.url)
      @attrs = attrs
      @orphan_mitigator = VCAP::Services::ServiceBrokers::V2::OrphanMitigator.new
      @state_poller = VCAP::Services::ServiceBrokers::V2::ServiceInstanceStatePoller.new
    end

    def catalog
      response = @http_client.get(CATALOG_PATH)
      @response_parser.parse(:get, CATALOG_PATH, response)
    end

    # The broker is expected to guarantee uniqueness of instance_id.
    # raises ServiceBrokerConflict if the id is already in use
    def provision(instance)
      path = "/v2/service_instances/#{instance.guid}?accepts_incomplete=true"

      response = @http_client.put(path, {
        service_id:        instance.service.broker_provided_id,
        plan_id:           instance.service_plan.broker_provided_id,
        organization_guid: instance.organization.guid,
        space_guid:        instance.space.guid,
      })

      parsed_response = @response_parser.parse(:put, path, response)
      instance.dashboard_url = parsed_response['dashboard_url']
      instance.state_description = parsed_response['state_description'] || ''

      if parsed_response['state']
        instance.state = parsed_response['state']
        @state_poller.poll_service_instance_state(@attrs, instance) if instance.state == 'creating'
      else
        instance.state = 'available'
      end

      # DEPRECATED, but needed because of not null constraint
      instance.credentials = {}
    rescue Errors::ServiceBrokerApiTimeout, Errors::ServiceBrokerBadResponse => e
      @orphan_mitigator.cleanup_failed_provision(@attrs, instance)
      raise e
    end

    def fetch_service_instance_state(instance)
      path = "/v2/service_instances/#{instance.guid}"

      response = @http_client.get(path)
      parsed_response = @response_parser.parse(:get, path, response)

      instance.dashboard_url = parsed_response['dashboard_url']
      instance.state = parsed_response['state']
      instance.state_description = parsed_response['state_description']
      instance
    end

    def bind(binding)
      path = "/v2/service_instances/#{binding.service_instance.guid}/service_bindings/#{binding.guid}"
      response = @http_client.put(path, {
        service_id:  binding.service.broker_provided_id,
        plan_id:     binding.service_plan.broker_provided_id,
        app_guid:    binding.app_guid
      })
      parsed_response = @response_parser.parse(:put, path, response)

      binding.credentials = parsed_response['credentials']
      if parsed_response.key?('syslog_drain_url')
        binding.syslog_drain_url = parsed_response['syslog_drain_url']
      end

    rescue Errors::ServiceBrokerApiTimeout, Errors::ServiceBrokerBadResponse => e
      @orphan_mitigator.cleanup_failed_bind(@attrs, binding)
      raise e
    end

    def unbind(binding)
      path = "/v2/service_instances/#{binding.service_instance.guid}/service_bindings/#{binding.guid}"

      response = @http_client.delete(path, {
        service_id: binding.service.broker_provided_id,
        plan_id:    binding.service_plan.broker_provided_id,
      })

      @response_parser.parse(:delete, path, response)
    end

    def deprovision(instance)
      path = "/v2/service_instances/#{instance.guid}"

      response = @http_client.delete(path, {
        service_id: instance.service.broker_provided_id,
        plan_id:    instance.service_plan.broker_provided_id,
      })

      @response_parser.parse(:delete, path, response)

    rescue VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerConflict => e
      raise VCAP::Errors::ApiError.new_from_details('ServiceInstanceDeprovisionFailed', e.message)
    end

    def update_service_plan(instance, plan)
      path = "/v2/service_instances/#{instance.guid}/"

      response = @http_client.patch(path, {
          plan_id:	plan.broker_provided_id,
          previous_values: {
            plan_id: instance.service_plan.broker_provided_id,
            service_id: instance.service.broker_provided_id,
            organization_id: instance.organization.guid,
            space_id: instance.space.guid
          }
      })

      @response_parser.parse(:put, path, response)
    end

    private

    def logger
      @logger ||= Steno.logger('cc.service_broker.v2.client')
    end
  end
end
