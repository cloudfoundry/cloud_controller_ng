module VCAP::Services::ServiceBrokers::V2
  class Client
    CATALOG_PATH = '/v2/catalog'.freeze
    PLATFORM     = 'cloudfoundry'.freeze

    attr_reader :orphan_mitigator, :attrs

    def initialize(attrs)
      http_client_attrs = attrs.slice(:url, :auth_username, :auth_password)
      @http_client      = VCAP::Services::ServiceBrokers::V2::HttpClient.new(http_client_attrs)
      @response_parser  = VCAP::Services::ServiceBrokers::V2::ResponseParser.new(@http_client.url)
      @attrs            = attrs
      @orphan_mitigator = VCAP::Services::ServiceBrokers::V2::OrphanMitigator.new
      @config           = VCAP::CloudController::Config.config
    end

    def catalog
      response = @http_client.get(CATALOG_PATH)
      @response_parser.parse_catalog(CATALOG_PATH, response)
    end

    def provision(instance, arbitrary_parameters: {}, accepts_incomplete: false)
      path = service_instance_resource_path(instance, accepts_incomplete: accepts_incomplete)

      body = {
        service_id:        instance.service.broker_provided_id,
        plan_id:           instance.service_plan.broker_provided_id,
        organization_guid: instance.organization.guid,
        space_guid:        instance.space.guid,
        context:           context_hash(instance)
      }

      body[:parameters] = arbitrary_parameters if arbitrary_parameters.present?

      begin
        response = @http_client.put(path, body)
      rescue Errors::HttpClientTimeout => e
        @orphan_mitigator.cleanup_failed_provision(@attrs, instance)
        raise e
      end

      parsed_response     = @response_parser.parse_provision(path, response)
      last_operation_hash = parsed_response['last_operation'] || {}
      return_values       = {
        instance:       {
          credentials:   {},
          dashboard_url: parsed_response['dashboard_url']
        },
        last_operation: {
          type:                      'create',
          description:               last_operation_hash['description'] || '',
          broker_provided_operation: async_response?(response) ? parsed_response['operation'] : nil
        }
      }

      state                                  = last_operation_hash['state']
      return_values[:last_operation][:state] = state || 'succeeded'

      return_values
    rescue Errors::ServiceBrokerBadResponse => e
      @orphan_mitigator.cleanup_failed_provision(@attrs, instance)
      raise e
    rescue Errors::ServiceBrokerResponseMalformed => e
      @orphan_mitigator.cleanup_failed_provision(@attrs, instance) unless e.status == 200
      raise e
    end

    def fetch_service_instance_last_operation(instance)
      path                = service_instance_last_operation_path(instance)
      response            = @http_client.get(path)
      parsed_response     = @response_parser.parse_fetch_state(path, response)
      last_operation_hash = parsed_response.delete('last_operation') || {}

      state = extract_state(instance, last_operation_hash)

      result = {
        last_operation:
          {
            state: state
          }
      }

      result[:last_operation][:description] = last_operation_hash['description'] if last_operation_hash['description']
      result.merge(parsed_response.symbolize_keys)
    end

    def create_service_key(key, arbitrary_parameters: {})
      path              = service_binding_resource_path(key.guid, key.service_instance.guid)
      body              = {
        service_id:    key.service.broker_provided_id,
        plan_id:       key.service_plan.broker_provided_id,
        bind_resource: { credential_client_id: @config.get(:cc_service_key_client_name) },
        context:       context_hash(key.service_instance),
      }

      body[:parameters] = arbitrary_parameters if arbitrary_parameters.present?

      begin
        response = @http_client.put(path, body)
      rescue Errors::HttpClientTimeout => e
        @orphan_mitigator.cleanup_failed_key(@attrs, key)
        raise e
      end

      parsed_response = @response_parser.parse_bind(path, response, service_guid: key.service.guid)

      { credentials: parsed_response['credentials'] }
    rescue Errors::ServiceBrokerBadResponse => e
      @orphan_mitigator.cleanup_failed_key(@attrs, key)
      raise e
    end

    def bind(binding, arbitrary_parameters: {}, accepts_incomplete: false)
      path              = service_binding_resource_path(binding.guid, binding.service_instance.guid, accepts_incomplete: accepts_incomplete)
      body              = {
        service_id:    binding.service.broker_provided_id,
        plan_id:       binding.service_plan.broker_provided_id,
        app_guid:      binding.try(:app_guid),
        bind_resource: binding.required_parameters,
        context:       context_hash(binding.service_instance)
      }
      body              = body.reject { |_, v| v.nil? }
      body[:parameters] = arbitrary_parameters if arbitrary_parameters.present?

      begin
        response = @http_client.put(path, body)
      rescue Errors::HttpClientTimeout => e
        @orphan_mitigator.cleanup_failed_bind(@attrs, binding)
        raise e
      end

      parsed_response = @response_parser.parse_bind(path, response, service_guid: binding.service.guid)

      attributes = {
        credentials: parsed_response['credentials'],
      }

      if parsed_response.key?('syslog_drain_url')
        attributes[:syslog_drain_url] = parsed_response['syslog_drain_url']
      end

      if parsed_response.key?('route_service_url')
        attributes[:route_service_url] = parsed_response['route_service_url']
      end

      if parsed_response.key?('volume_mounts')
        attributes[:volume_mounts] = parsed_response['volume_mounts']
      end

      {
        async: async_response?(response),
        binding: attributes,
        operation: parsed_response['operation']
      }
    rescue Errors::ServiceBrokerBadResponse,
           Errors::ServiceBrokerInvalidVolumeMounts,
           Errors::ServiceBrokerInvalidSyslogDrainUrl => e
      @orphan_mitigator.cleanup_failed_bind(@attrs, binding)
      raise e
    end

    def unbind(service_binding, user_guid=nil, accepts_incomplete=false)
      path = service_binding_resource_path(service_binding.guid, service_binding.service_instance.guid, accepts_incomplete: accepts_incomplete)

      body = {
        service_id: service_binding.service.broker_provided_id,
        plan_id:    service_binding.service_plan.broker_provided_id,
      }
      body[:accepts_incomplete] = true if accepts_incomplete
      response = @http_client.delete(path, body, user_guid)

      parsed_response = @response_parser.parse_unbind(path, response)

      {
        async: async_response?(response),
        operation: parsed_response['operation']
      }
    rescue => e
      raise e.exception("Service broker failed to delete service binding for instance #{service_binding&.service_instance&.name}: #{e.message}")
    end

    def fetch_service_binding_last_operation(service_binding)
      path = service_binding_last_operation_path(service_binding)
      response = @http_client.get(path)
      parsed_response = @response_parser.parse_fetch_service_binding_last_operation(path, response)
      last_operation_hash = parsed_response['last_operation'] || {}

      {}.tap do |result|
        result[:last_operation] = {}
        result[:last_operation][:state] = extract_state(service_binding, last_operation_hash)
        result[:last_operation][:description] = last_operation_hash['description'] if last_operation_hash['description']
      end
    end

    def deprovision(instance, accepts_incomplete: false)
      path = service_instance_resource_path(instance)

      body = {
        service_id: instance.service.broker_provided_id,
        plan_id:    instance.service_plan.broker_provided_id,
      }
      body[:accepts_incomplete] = true if accepts_incomplete
      response                  = @http_client.delete(path, body)

      parsed_response     = @response_parser.parse_deprovision(path, response) || {}
      last_operation_hash = parsed_response['last_operation'] || {}
      state               = last_operation_hash['state']

      {
        last_operation: {
                          type:                      'delete',
                          description:               last_operation_hash['description'] || '',
                          state:                     state || 'succeeded',
                          broker_provided_operation: async_response?(response) ? parsed_response['operation'] : nil
                        }.compact
      }
    rescue VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerConflict => e
      raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceDeprovisionFailed', e.message)
    rescue => e
      raise e.exception("Service instance #{instance.name}: #{e.message}")
    end

    def update(instance, plan, accepts_incomplete: false, arbitrary_parameters: nil, previous_values: {})
      path = service_instance_resource_path(instance, accepts_incomplete: accepts_incomplete)

      body = {
        service_id:      instance.service.broker_provided_id,
        plan_id:         plan.broker_provided_id,
        previous_values: previous_values,
        context:         context_hash(instance)
      }
      body[:parameters] = arbitrary_parameters if arbitrary_parameters
      response          = @http_client.patch(path, body)

      parsed_response     = @response_parser.parse_update(path, response)
      last_operation_hash = parsed_response['last_operation'] || {}
      state               = last_operation_hash['state'] || 'succeeded'
      dashboard_url       = parsed_response['dashboard_url']

      attributes = {
        last_operation: {
          type:                      'update',
          state:                     state,
          description:               last_operation_hash['description'] || '',
          broker_provided_operation: async_response?(response) ? parsed_response['operation'] : nil
        },
      }

      if dashboard_url
        attributes[:dashboard_url] = dashboard_url
      end

      if state == 'in progress'
        attributes[:last_operation][:proposed_changes] = { service_plan_guid: plan.guid }
      end

      [attributes, nil]
    rescue Errors::ServiceBrokerBadResponse,
           Errors::ServiceBrokerApiTimeout,
           Errors::ServiceBrokerResponseMalformed,
           Errors::ServiceBrokerRequestRejected,
           Errors::AsyncRequired => e

      attributes = {
        last_operation: {
          state:       'failed',
          type:        'update',
          description: e.message
        }
      }
      [attributes, e]
    end

    def fetch_service_instance(instance)
      path = service_instance_resource_path(instance)
      response = @http_client.get(path)
      @response_parser.parse_fetch_instance_parameters(path, response).deep_symbolize_keys
    end

    def fetch_service_binding(service_binding)
      path = service_binding_resource_path(service_binding.guid, service_binding.service_instance.guid)
      response = @http_client.get(path)
      @response_parser.parse_fetch_binding_parameters(path, response).deep_symbolize_keys
    end

    private

    def context_hash(service_instance)
      {
        platform:          PLATFORM,
        organization_guid: service_instance.organization.guid,
        space_guid:        service_instance.space.guid
      }
    end

    def async_response?(response)
      response.code == 202
    end

    def extract_state(broker_resource, last_operation_hash)
      return last_operation_hash['state'] unless last_operation_hash.empty?

      if broker_resource.last_operation.type == 'delete'
        'succeeded'
      else
        'in progress'
      end
    end

    def service_instance_last_operation_path(instance)
      query_params = {}.tap do |q|
        q['plan_id']    = instance.service_plan.broker_provided_id
        q['service_id'] = instance.service.broker_provided_id
        q['operation']  = instance.last_operation.broker_provided_operation if instance.last_operation.broker_provided_operation
      end

      "#{service_instance_resource_path(instance)}/last_operation?#{query_params.to_query}"
    end

    def service_binding_resource_path(binding_guid, service_instance_guid, opts={})
      path = "/v2/service_instances/#{service_instance_guid}/service_bindings/#{binding_guid}"
      if opts[:accepts_incomplete]
        path += '?accepts_incomplete=true'
      end
      path
    end

    def service_binding_last_operation_path(service_binding)
      query_params = {
       'service_id' => service_binding.service_instance.service.broker_provided_id,
       'plan_id' => service_binding.service_instance.service_plan.broker_provided_id
      }

      if service_binding.last_operation.broker_provided_operation
        query_params['operation'] = service_binding.last_operation.broker_provided_operation
      end
      "#{service_binding_resource_path(service_binding.guid, service_binding.service_instance.guid)}/last_operation?#{query_params.to_query}"
    end

    def service_instance_resource_path(instance, opts={})
      path = "/v2/service_instances/#{instance.guid}"
      if opts[:accepts_incomplete]
        path += '?accepts_incomplete=true'
      end
      path
    end
  end
end
