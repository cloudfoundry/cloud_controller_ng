require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "Quota Definitions", type: :api do
  let(:admin_auth_header) { headers_for(admin_user, :admin_scope => true)["HTTP_AUTHORIZATION"] }
  authenticated_request

  field :guid, "The guid of the quota definition.", required: false
  field :name, "The name for the quota definition.", required: true, example_values: ["gold_quota"]
  field :non_basic_services_allowed, "If an organization can have non basic services", required: true, valid_values: [true, false]
  field :total_services, "How many services an organization can have.", required: true, example_values: [5, 201]
  field :total_routes, "How many routes an organization can have.", required: true, example_values: [10, 23]
  field :memory_limit, "How much memory in megabyte an organization can have.", required: true, example_values: [5_120, 10_024]
  field :trial_db_allowed, "If an organization can have a trial db.", required: false, deprecated: true

  let(:guid) { VCAP::CloudController::QuotaDefinition.first.guid }

  standard_model_list(:quota_definition, VCAP::CloudController::QuotaDefinitionsController)
  standard_model_get(:quota_definition)
  standard_model_delete(:quota_definition)

  post "/v2/quota_definitions" do
    example "Creating a quota definition" do
      client.post "/v2/quota_definitions", fields_json, headers
      expect(status).to eq(201)

      standard_entity_response parsed_response, :quota_definition
    end
  end

  put "/v2/quota_definitions/:guid" do
    example "Updating a quota definition" do
      client.put "/v2/quota_definitions/#{guid}", fields_json, headers
      expect(status).to eq(201)

      standard_entity_response parsed_response, :quota_definition
    end
  end
end
