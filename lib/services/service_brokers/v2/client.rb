module VCAP::Services::ServiceBrokers::V2
  class Client
    CATALOG_PATH = '/v2/catalog'.freeze

    attr_reader :orphan_mitigator, :attrs

    def initialize(attrs)
      http_client_attrs = attrs.slice(:url, :auth_username, :auth_password)
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
    def provision(instance, opts={})
      event_repository_opts = opts.fetch(:event_repository_opts)
      request_attrs = opts.fetch(:request_attrs)

      path = "/v2/service_instances/#{instance.guid}"
      if opts[:accepts_incomplete]
        path += '?accepts_incomplete=true'
      end

      response = @http_client.put(path, {
        service_id:        instance.service.broker_provided_id,
        plan_id:           instance.service_plan.broker_provided_id,
        organization_guid: instance.organization.guid,
        space_guid:        instance.space.guid,
      })

      parsed_response = @response_parser.parse(:put, path, response)
      last_operation_hash = parsed_response['last_operation'] || {}
      poll_interval_seconds = last_operation_hash['async_poll_interval_seconds'].try(:to_i)
      attributes = {
        # DEPRECATED, but needed because of not null constraint
        credentials: {},
        dashboard_url: parsed_response['dashboard_url'],
        last_operation: {
          type: 'create',
          description: last_operation_hash['description'] || '',
        },
      }

      state = last_operation_hash['state']
      if state
        attributes[:last_operation][:state] = state
        if attributes[:last_operation][:state] == 'in progress'
          @state_poller.poll_service_instance_state(@attrs, instance, event_repository_opts, request_attrs, poll_interval_seconds)
        end
      else
        attributes[:last_operation][:state] = 'succeeded'
      end

      attributes
    rescue Errors::ServiceBrokerApiTimeout, Errors::ServiceBrokerBadResponse => e
      @orphan_mitigator.cleanup_failed_provision(@attrs, instance)
      raise e
    rescue Errors::ServiceBrokerResponseMalformed => e
      @orphan_mitigator.cleanup_failed_provision(@attrs, instance) unless e.status == 200
      raise e
    end

    def fetch_service_instance_state(instance)
      path = "/v2/service_instances/#{instance.guid}"

      response = @http_client.get(path)
      parsed_response = @response_parser.parse_fetch_state(:get, path, response)
      last_operation_hash = parsed_response['last_operation'] || {}

      if parsed_response.empty?
        state = (instance.last_operation.type == 'delete' ? 'succeeded' : 'failed')
        {
          last_operation: {
            state: state,
            description: ''
          }
        }
      else
        {
          dashboard_url:  parsed_response['dashboard_url'],
          last_operation: {
            state:        last_operation_hash['state'],
            description:  last_operation_hash['description'],
          }
        }
      end
    end

    def bind(binding)
      path = "/v2/service_instances/#{binding.service_instance.guid}/service_bindings/#{binding.guid}"
      response = @http_client.put(path, {
        service_id:  binding.service.broker_provided_id,
        plan_id:     binding.service_plan.broker_provided_id,
        app_guid:    binding.app_guid
      })
      parsed_response = @response_parser.parse(:put, path, response)

      attributes = {
        credentials: parsed_response['credentials']
      }
      if parsed_response.key?('syslog_drain_url')
        attributes[:syslog_drain_url] = parsed_response['syslog_drain_url']
      end

      attributes
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

    def deprovision(instance, opts={})
      event_repository_opts = opts[:event_repository_opts]
      request_attrs = opts[:request_attrs]

      path = "/v2/service_instances/#{instance.guid}"

      request_params = {
        service_id: instance.service.broker_provided_id,
        plan_id:    instance.service_plan.broker_provided_id,
      }
      request_params.merge!(accepts_incomplete: true) if opts[:accepts_incomplete] == true
      response = @http_client.delete(path, request_params)

      parsed_response = @response_parser.parse(:delete, path, response) || {}

      last_operation = parsed_response['last_operation'] || {}
      poll_interval = last_operation['async_poll_interval_seconds'].try(:to_i)

      if last_operation['state'] == 'in progress'
        @state_poller.poll_service_instance_state(@attrs, instance, event_repository_opts, request_attrs, poll_interval)
      end

      parsed_response ||= {}
      last_operation_hash = parsed_response['last_operation'] || {}
      {
        last_operation: {
          state:        last_operation_hash['state'],
          description:  last_operation_hash['description'],
        }
      }
    rescue VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerConflict => e
      raise VCAP::Errors::ApiError.new_from_details('ServiceInstanceDeprovisionFailed', e.message)
    end

    def update_service_plan(instance, plan, opts={})
      event_repository_opts = opts.fetch(:event_repository_opts)
      request_attrs = opts.fetch(:request_attrs)

      path = "/v2/service_instances/#{instance.guid}"
      if opts[:accepts_incomplete]
        path += '?accepts_incomplete=true'
      end

      response = @http_client.patch(path, {
          plan_id:	plan.broker_provided_id,
          previous_values: {
            plan_id: instance.service_plan.broker_provided_id,
            service_id: instance.service.broker_provided_id,
            organization_id: instance.organization.guid,
            space_id: instance.space.guid
          }
      })

      parsed_response = @response_parser.parse(:patch, path, response)
      last_operation_hash = parsed_response['last_operation'] || {}
      poll_interval_seconds = last_operation_hash['async_poll_interval_seconds'].try(:to_i)

      attributes = {
        last_operation: {
          type: 'update',
          description: last_operation_hash['description'] || '',
        },
      }

      state = last_operation_hash['state']
      if state
        attributes[:last_operation][:state] = state
        attributes[:last_operation][:proposed_changes] = { service_plan_guid: plan.guid }
        if attributes[:last_operation][:state] == 'in progress'
          @state_poller.poll_service_instance_state(@attrs, instance, event_repository_opts, request_attrs, poll_interval_seconds)
        end
      else
        attributes[:last_operation][:state] = 'succeeded'
        attributes[:service_plan] = plan
      end

      return attributes, nil
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
      return attributes, e
    end

    private

    def logger
      @logger ||= Steno.logger('cc.service_broker.v2.client')
    end
  end
end
