require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource 'Space Quota Definitions', type: [:api, :legacy_api] do
  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }
  let(:space_quota_definition) { VCAP::CloudController::SpaceQuotaDefinition.make }
  let!(:guid) { space_quota_definition.guid }

  authenticated_request

  shared_context 'guid_parameter' do
    parameter :guid, 'The guid of the Space Quota Definition'
  end

  shared_context 'updatable_fields' do |opts|
    field :name, 'The name for the Space Quota Definition.', required: opts[:required], example_values: ['gold_quota']
    field :non_basic_services_allowed, 'If a space can have non basic services', required: opts[:required], valid_values: [true, false]
    field :total_services, 'How many services a space can have.', required: opts[:required], example_values: [5, 201]
    field :total_routes, 'How many routes a space can have.', required: opts[:required], example_values: [10, 23]
    field :memory_limit, 'How much memory in megabytes a space can have.', required: opts[:required], example_values: [5_120, 10_024]

    field :instance_memory_limit,
      'The maximum amount of memory in megabytes an application instance can have. (-1 represents an unlimited amount)',
      default: -1,
      example_values: [-1, 10_024]

    field :organization_guid, 'The owning organization of the space quota', required: opts[:required], example_values: [Sham.guid]
  end

  standard_model_list :space_quota_definition, VCAP::CloudController::SpaceQuotaDefinitionsController
  standard_model_get :space_quota_definition, nested_associations: [:organization]
  standard_model_delete :space_quota_definition

  post '/v2/space_quota_definitions' do
    include_context 'updatable_fields', required: true
    example 'Creating a Space Quota Definition' do
      organization_guid = VCAP::CloudController::Organization.make.guid
      client.post '/v2/space_quota_definitions', MultiJson.dump(required_fields.merge(organization_guid: organization_guid), pretty: true), headers

      expect(status).to eq(201)
      standard_entity_response parsed_response, :space_quota_definition
    end
  end

  put '/v2/space_quota_definitions/:guid' do
    include_context 'guid_parameter'
    include_context 'updatable_fields', required: false
    example 'Updating a Space Quota Definition' do
      client.put "/v2/space_quota_definitions/#{guid}", fields_json, headers

      expect(status).to eq(201)
      standard_entity_response parsed_response, :space_quota_definition
    end
  end

  describe 'Nested endpoints' do
    include_context 'guid_parameter'

    describe 'Spaces' do
      before do
        space_quota_definition.add_space(associated_space)
      end
      let!(:space) { VCAP::CloudController::Space.make(organization_guid: space_quota_definition.organization_guid) }
      let(:space_guid) { space.guid }
      let(:associated_space) { VCAP::CloudController::Space.make(organization_guid: space_quota_definition.organization_guid) }
      let(:associated_space_guid) { associated_space.guid }

      standard_model_list :space, VCAP::CloudController::SpacesController, outer_model: :space_quota_definition
      nested_model_associate :space, :space_quota_definition
      nested_model_remove :space, :space_quota_definition
    end
  end
end
