require 'spec_helper'
require 'rspec_api_documentation/dsl'

RSpec.resource 'Organization Quota Definitions', type: [:api, :legacy_api] do
  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }
  let(:guid) { VCAP::CloudController::QuotaDefinition.make.guid }

  authenticated_request

  shared_context 'guid_parameter' do
    parameter :guid, 'The guid of the Organization Quota Definition'
  end

  shared_context 'updatable_fields' do |opts|
    field :name, 'The name for the Organization Quota Definition.', required: opts[:required], example_values: ['gold_quota']
    field :non_basic_services_allowed, 'If an organization can have non basic services', required: opts[:required], valid_values: [true, false]
    field :total_services, 'How many services an organization can have. (-1 represents an unlimited amount)', required: opts[:required], example_values: [-1, 5, 201]
    field :total_service_keys, 'How many service keys an organization can have. (-1 represents an unlimited amount)', example_values: [-1, 5, 201], default: -1
    field :total_routes, 'How many routes an organization can have. (-1 represents an unlimited amount)', required: opts[:required], example_values: [-1, 10, 23]
    field :total_reserved_route_ports,
      'How many routes an organization can have that use a reserved port. These routes count toward total_routes. (-1 represents an unlimited amount)',
      default: 0,
      example_values: [-1, 10, 20]

    field :total_private_domains,
      'How many private domains an organization can have. (-1 represents an unlimited amount)',
      example_values: [-1, 10, 23], default: -1
    field :memory_limit, 'How much memory in megabyte an organization can have.', required: opts[:required], example_values: [5_120, 9999]

    field :instance_memory_limit,
      'The maximum amount of memory in megabyte an application instance can have. (-1 represents an unlimited amount)',
      required: opts[:required],
      default: -1,
      example_values: [-1, 10_240, 9999]

    field :trial_db_allowed, 'If an organization can have a trial db.', deprecated: true
    field :app_instance_limit,
      'How many app instances an organization can create. (-1 represents an unlimited amount)',
      example_values: [-1, 10, 23], default: -1
    field :app_task_limit, 'The number of tasks that can be run per app. (-1 represents an unlimited amount)',
      default: -1,
      experimental: true,
      example_values: [-1, 10]
  end

  standard_model_list(:quota_definition, VCAP::CloudController::QuotaDefinitionsController, title: 'Organization Quota Definitions')
  standard_model_get(:quota_definition, title: 'Organization Quota Definition')
  standard_model_delete(:quota_definition, title: 'Organization Quota Definition')

  post '/v2/quota_definitions' do
    include_context 'updatable_fields', required: true
    example 'Creating a Organization Quota Definition' do
      client.post '/v2/quota_definitions',
        fields_json(instance_memory_limit: 10_240, app_instance_limit: 10, app_task_limit: 5, total_routes: 4, total_reserved_route_ports: 3),
        headers

      expect(status).to eq(201)

      standard_entity_response parsed_response, :quota_definition,
        expected_values: { instance_memory_limit: 10_240, app_instance_limit: 10, app_task_limit: 5, total_reserved_route_ports: 3 }

      expect(parsed_response['entity']).to include('instance_memory_limit')
      expect(parsed_response['entity']).to include('app_instance_limit')
      expect(parsed_response['entity']).to include('app_task_limit')
      expect(parsed_response['entity']).to include('total_reserved_route_ports')
      expect(parsed_response['entity']).to include('total_routes')
    end
  end

  put '/v2/quota_definitions/:guid' do
    include_context 'guid_parameter'
    include_context 'updatable_fields', required: false
    example 'Updating a Organization Quota Definition' do
      client.put "/v2/quota_definitions/#{guid}", fields_json, headers
      expect(status).to eq(201)

      standard_entity_response parsed_response, :quota_definition

      expect(parsed_response['entity']).to include('instance_memory_limit')
      expect(parsed_response['entity']).to include('app_instance_limit')
      expect(parsed_response['entity']).to include('app_task_limit')
      expect(parsed_response['entity']).to include('total_reserved_route_ports')
      expect(parsed_response['entity']).to include('total_routes')
    end
  end
end
