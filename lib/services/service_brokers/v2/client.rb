require 'presenters/mixins/metadata_presentation_helpers'

module VCAP::Services::ServiceBrokers::V2
  class Client
    include VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers

    CATALOG_PATH = '/v2/catalog'.freeze
    PLATFORM = 'cloudfoundry'.freeze

    attr_reader :orphan_mitigator

    def initialize(attrs)
      http_client_attrs = attrs.slice(:url, :auth_username, :auth_password)
      @http_client = VCAP::Services::ServiceBrokers::V2::HttpClient.new(http_client_attrs)
      @response_parser = VCAP::Services::ServiceBrokers::V2::ResponseParser.new(@http_client.url)
      @orphan_mitigator = VCAP::Services::ServiceBrokers::V2::OrphanMitigator.new
      @config = VCAP::CloudController::Config.config
    end

    def catalog(user_guid: nil)
      response = @http_client.get(CATALOG_PATH, user_guid: user_guid)
      @response_parser.parse_catalog(CATALOG_PATH, response)
    end

    def provision(instance, arbitrary_parameters: {}, accepts_incomplete: false, maintenance_info: nil, user_guid: nil)
      path = service_instance_resource_path(instance, accepts_incomplete: accepts_incomplete)

      body = {
        service_id: instance.service.broker_provided_id,
        plan_id: instance.service_plan.broker_provided_id,
        organization_guid: instance.organization.guid,
        space_guid: instance.space.guid,
        context: context_hash_with_instance_name_and_annotations(instance)
      }

      body[:parameters] = arbitrary_parameters if arbitrary_parameters.present?
      body[:maintenance_info] = maintenance_info if maintenance_info.present?

      begin
        response = @http_client.put(path, body, user_guid: user_guid)
      rescue Errors::HttpClientTimeout => e
        @orphan_mitigator.cleanup_failed_provision(instance)
        raise e
      end

      parsed_response = @response_parser.parse_provision(path, response)
      last_operation_hash = parsed_response['last_operation'] || {}
      return_values = {
        instance: {
          credentials: {},
          dashboard_url: parsed_response['dashboard_url']
        },
        last_operation: {
          type: 'create',
          description: last_operation_hash['description'] || '',
          broker_provided_operation: async_response?(response) ? parsed_response['operation'] : nil
        }
      }

      state = last_operation_hash['state']
      return_values[:last_operation][:state] = state || 'succeeded'

      return_values
    rescue Errors::ServiceBrokerBadResponse => e
      @orphan_mitigator.cleanup_failed_provision(instance)
      raise e
    rescue Errors::ServiceBrokerResponseMalformed => e
      @orphan_mitigator.cleanup_failed_provision(instance) unless e.status == 200
      raise e
    end

    def create_service_key(key, arbitrary_parameters: {}, user_guid: nil)
      path = service_binding_resource_path(key.guid, key.service_instance.guid)
      body = {
        service_id: key.service.broker_provided_id,
        plan_id: key.service_plan.broker_provided_id,
        bind_resource: {},
        context: context_hash(key.service_instance),
      }

      body[:bind_resource][:credential_client_id] = @config.get(:cc_service_key_client_name) if @config.get(:cc_service_key_client_name).present?
      body[:parameters] = arbitrary_parameters if arbitrary_parameters.present?

      begin
        response = @http_client.put(path, body, user_guid: user_guid)
      rescue Errors::HttpClientTimeout => e
        @orphan_mitigator.cleanup_failed_key(key)
        raise e
      end

      parsed_response = @response_parser.parse_bind(path, response, service_guid: key.service.guid)

      { credentials: parsed_response['credentials'] }
    rescue Errors::ServiceBrokerBadResponse,
           Errors::ServiceBrokerResponseMalformed => e
      @orphan_mitigator.cleanup_failed_key(key)
      raise e
    end

    def bind(binding, arbitrary_parameters: {}, accepts_incomplete: false, user_guid: nil)
      path = service_binding_resource_path(binding.guid, binding.service_instance.guid, accepts_incomplete: accepts_incomplete)
      body = {
        service_id: binding.service.broker_provided_id,
        plan_id: binding.service_plan.broker_provided_id,
        app_guid: binding.try(:app_guid),
        bind_resource: bind_resource(binding),
        context: context_hash(binding.service_instance)
      }
      body = body.compact
      body[:parameters] = arbitrary_parameters if arbitrary_parameters.present?

      begin
        response = @http_client.put(path, body, user_guid: user_guid)
      rescue Errors::HttpClientTimeout => e
        @orphan_mitigator.cleanup_failed_bind(binding)
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
           Errors::ServiceBrokerInvalidSyslogDrainUrl,
           Errors::ServiceBrokerResponseMalformed => e
      unless e.instance_of?(Errors::ServiceBrokerResponseMalformed) && e.status == 200
        @orphan_mitigator.cleanup_failed_bind(binding)
      end

      raise e
    end

    def unbind(service_binding, user_guid: nil, accepts_incomplete: false)
      path = service_binding_resource_path(service_binding.guid, service_binding.service_instance.guid, accepts_incomplete: accepts_incomplete)

      body = {
        service_id: service_binding.service.broker_provided_id,
        plan_id: service_binding.service_plan.broker_provided_id,
      }
      body[:accepts_incomplete] = true if accepts_incomplete
      response = @http_client.delete(path, body, user_guid: user_guid)

      parsed_response = @response_parser.parse_unbind(path, response)

      {
        async: async_response?(response),
        operation: parsed_response['operation']
      }
    rescue VCAP::Services::ServiceBrokers::V2::Errors::ConcurrencyError => e
      if service_binding.is_a? VCAP::CloudController::ServiceBinding
        raise CloudController::Errors::ApiError.new_from_details('AsyncServiceBindingOperationInProgress', service_binding.app.name, service_binding.service_instance.name)
      end

      raise e
    end

    def update(instance, plan, accepts_incomplete: false, arbitrary_parameters: nil, previous_values: {}, maintenance_info: nil, name: instance.name, user_guid: nil)
      path = service_instance_resource_path(instance, accepts_incomplete: accepts_incomplete)

      body = {
        service_id: instance.service.broker_provided_id,
        plan_id: plan.broker_provided_id,
        previous_values: previous_values,
        context: context_hash_with_instance_name(instance, name: name)
      }
      body[:parameters] = arbitrary_parameters if arbitrary_parameters
      body[:maintenance_info] = maintenance_info if maintenance_info
      response = @http_client.patch(path, body, user_guid: user_guid)

      parsed_response = @response_parser.parse_update(path, response)
      last_operation_hash = parsed_response['last_operation'] || {}
      state = last_operation_hash['state'] || 'succeeded'
      dashboard_url = parsed_response['dashboard_url']

      attributes = {
        last_operation: {
          type: 'update',
          state: state,
          description: last_operation_hash['description'] || '',
          broker_provided_operation: async_response?(response) ? parsed_response['operation'] : nil
        },
      }

      if dashboard_url
        attributes[:dashboard_url] = dashboard_url
      end

      if state == 'in progress'
        proposed_changes = { service_plan_guid: plan.guid }
        proposed_changes[:maintenance_info] = maintenance_info if maintenance_info
        attributes[:last_operation][:proposed_changes] = proposed_changes
      end

      [attributes, nil]
    rescue Errors::ServiceBrokerBadResponse,
           Errors::ServiceBrokerApiTimeout,
           Errors::ServiceBrokerResponseMalformed,
           Errors::ServiceBrokerRequestRejected,
           Errors::AsyncRequired => e

      attributes = {
        last_operation: {
          state: 'failed',
          type: 'update',
          description: e.message
        }
      }
      [attributes, e]
    end

    def deprovision(instance, accepts_incomplete: false, user_guid: nil)
      path = service_instance_resource_path(instance)

      body = {
        service_id: instance.service.broker_provided_id,
        plan_id: instance.service_plan.broker_provided_id,
      }
      body[:accepts_incomplete] = true if accepts_incomplete
      response = @http_client.delete(path, body, user_guid: user_guid)

      parsed_response = @response_parser.parse_deprovision(path, response) || {}
      last_operation_hash = parsed_response['last_operation'] || {}
      state = last_operation_hash['state']

      {
        last_operation: {
          type: 'delete',
          description: last_operation_hash['description'] || '',
          state: state || 'succeeded',
          broker_provided_operation: async_response?(response) ? parsed_response['operation'] : nil
        }.compact
      }
    rescue VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerConflict => e
      raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceDeprovisionFailed', e.message)
    rescue VCAP::Services::ServiceBrokers::V2::Errors::ConcurrencyError
      raise CloudController::Errors::ApiError.new_from_details('AsyncServiceInstanceOperationInProgress', instance.name)
    rescue => e
      raise e.exception("Service instance #{instance.name}: #{e.message}")
    end

    def fetch_service_instance_last_operation(instance, user_guid: nil)
      path = service_instance_last_operation_path(instance)
      response = @http_client.get(path, user_guid: user_guid)
      parsed_response = @response_parser.parse_fetch_state(path, response)
      last_operation_hash = parsed_response.delete('last_operation') || {}

      result = {
        last_operation:
          {
            state: extract_state(instance, last_operation_hash)
          }
      }

      result[:last_operation][:description] = last_operation_hash['description'] if last_operation_hash['description']
      result[:retry_after] = response[HttpResponse::HEADER_RETRY_AFTER] if response[HttpResponse::HEADER_RETRY_AFTER]
      result.merge(parsed_response.symbolize_keys)
    end

    def fetch_service_binding_last_operation(service_binding, user_guid: nil)
      path = service_binding_last_operation_path(service_binding)
      response = @http_client.get(path, user_guid: user_guid)
      parsed_response = @response_parser.parse_fetch_service_binding_last_operation(path, response)
      last_operation_hash = parsed_response['last_operation'] || {}

      {}.tap do |result|
        result[:last_operation] = {}
        result[:last_operation][:state] = extract_state(service_binding, last_operation_hash)
        result[:last_operation][:description] = last_operation_hash['description'] if last_operation_hash['description']
        result[:retry_after] = response[HttpResponse::HEADER_RETRY_AFTER] if response[HttpResponse::HEADER_RETRY_AFTER]
      end
    end

    def fetch_and_handle_service_binding_last_operation(service_binding, user_guid: nil)
      fetch_service_binding_last_operation(service_binding, user_guid: user_guid)
    rescue Errors::HttpClientTimeout,
           Errors::ServiceBrokerApiUnreachable,
           HttpRequestError,
           Errors::ServiceBrokerBadResponse,
           Errors::ServiceBrokerRequestRejected,
           Errors::ServiceBrokerApiAuthenticationFailed,
           Errors::ServiceBrokerResponseMalformed,
           HttpResponseError
      result = {}
      result[:last_operation] = {}
      result[:last_operation][:state] = 'in progress'
      result
    rescue => e
      raise e.exception("Service binding polling #{service_binding.guid}: #{e.message}")
    end

    def fetch_service_instance(instance, user_guid: nil)
      path = service_instance_resource_path(instance)
      response = @http_client.get(path, user_guid: user_guid)
      @response_parser.parse_fetch_instance_parameters(path, response).deep_symbolize_keys
    end

    def fetch_service_binding(service_binding, user_guid: nil)
      path = service_binding_resource_path(service_binding.guid, service_binding.service_instance.guid)
      response = @http_client.get(path, user_guid: user_guid)
      @response_parser.parse_fetch_binding_parameters(path, response).deep_symbolize_keys
    end

    private

    def bind_resource(binding)
      case binding
      when VCAP::CloudController::ServiceBinding
        {
          app_guid: binding.app_guid,
          space_guid: binding.space.guid,
          app_annotations: hashified_public_annotations(binding.app.annotations)
        }
      when VCAP::CloudController::ServiceKey
        if @config.get(:cc_service_key_client_name).present?
          return { credential_client_id: @config.get(:cc_service_key_client_name) }
        end

        {}
      when VCAP::CloudController::RouteBinding
        { route: binding.route.uri }
      else
        {}
      end
    end

    def context_hash_with_instance_name(service_instance, name: service_instance.name)
      context_hash(service_instance).merge(instance_name: name)
    end

    def context_hash_with_instance_name_and_annotations(service_instance, name: service_instance.name)
      context_hash(service_instance).merge(
        instance_name: name,
        instance_annotations: hashified_public_annotations(service_instance.annotations)
      )
    end

    def context_hash(service_instance)
      {
        platform: PLATFORM,
        organization_guid: service_instance.organization.guid,
        space_guid: service_instance.space.guid,
        organization_name: service_instance.organization.name,
        space_name: service_instance.space.name,
        organization_annotations: hashified_public_annotations(service_instance.organization.annotations),
        space_annotations: hashified_public_annotations(service_instance.space.annotations)
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
        q['plan_id'] = instance.service_plan.broker_provided_id
        q['service_id'] = instance.service.broker_provided_id
        q['operation'] = instance.last_operation.broker_provided_operation if instance.last_operation.broker_provided_operation
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

    def hashified_public_annotations(annotations)
      public_annotations = []
      annotations.each do |annotation, _|
        prefix, _ = VCAP::CloudController::MetadataHelpers.extract_prefix(annotation.key)
        public_annotations.append(annotation) if annotation.key_prefix.present? || prefix.present?
      end
      hashified_annotations(public_annotations)
    end
  end
end
