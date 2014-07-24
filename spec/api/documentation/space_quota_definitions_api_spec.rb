require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "Space Quota Definitions (experimental)", type: :api do
  let(:admin_auth_header) { admin_headers["HTTP_AUTHORIZATION"] }
  let!(:guid) { VCAP::CloudController::SpaceQuotaDefinition.make.guid }

  authenticated_request

  shared_context "guid_parameter" do
    parameter :guid, "The guid of the Space Quota Definition"
  end

  shared_context "updatable_fields" do
    field :name, "The name for the Space Quota Definition.", required: true, example_values: ["gold_quota"]
    field :non_basic_services_allowed, "If a space can have non basic services", required: true, valid_values: [true, false]
    field :total_services, "How many services a space can have.", required: true, example_values: [5, 201]
    field :total_routes, "How many routes a space can have.", required: true, example_values: [10, 23]
    field :memory_limit, "How much memory in megabytes a space can have.", required: true, example_values: [5_120, 10_024]
    field :instance_memory_limit, "The maximum amount of memory in megabytes an application instance can have. (-1 represents an unlimited amount)", default: -1, example_values: [-1, 10_024]
    field :organization_guid, "The owning organization of the space quota", required: true, example_values: [Sham.guid]
  end

  standard_model_list :space_quota_definition, VCAP::CloudController::SpaceQuotaDefinitionsController
  standard_model_get :space_quota_definition, nested_associations: [:organization]
  standard_model_delete :space_quota_definition

  post "/v2/space_quota_definitions" do
    include_context "updatable_fields"
    example "Creating a Space Quota Definition" do
      organization_guid = VCAP::CloudController::Organization.make.guid
      client.post "/v2/space_quota_definitions", MultiJson.dump(required_fields.merge(organization_guid: organization_guid)), headers

      expect(status).to eq(201)
      standard_entity_response parsed_response, :space_quota_definition
    end
  end

  put "/v2/space_quota_definitions/:guid" do
    include_context "guid_parameter"
    include_context "updatable_fields"
    example "Updating a Space Quota Definition" do
      client.put "/v2/space_quota_definitions/#{guid}", fields_json, headers

      expect(status).to eq(201)
      standard_entity_response parsed_response, :space_quota_definition
    end
  end
end
