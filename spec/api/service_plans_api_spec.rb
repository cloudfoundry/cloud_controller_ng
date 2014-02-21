require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "Services Plans", type: :api do
  before do
    VCAP::CloudController::Service.make
    VCAP::CloudController::ServicePlan.make(service_guid: service_guid)
  end

  let(:admin_auth_header) { headers_for(admin_user, :admin_scope => true)["HTTP_AUTHORIZATION"] }
  let(:guid) { VCAP::CloudController::ServicePlan.first.guid }
  let(:service_guid) { VCAP::CloudController::Service.first.guid }
  authenticated_request

  field :guid, "The guid of the service plan", required: false
  field :name, "The name of the service plan", required: true, example_values: ["100mb"]
  field :free, "A boolean describing if the service plan is free", required: true, valid_values: [true, false]
  field :description, "A description of the service plan", required: true, example_values: ["Let's you put data in your database!"]
  field :extra, "A JSON string with additional data about the plan", required: false, default: nil, example_values: ['{"cost": "$2.00"}']
  field :unique_id, "A guid for the service plan in the service broker (not the same as the cloud controller guid)", required: false, default: nil
  field :public, "A boolean describing that the plan is visible to the all users", required: false, default: true
  field :service_guid, "The guid of the related service", required: true, example_values: ["deadbeef"]

  standard_model_list(:service_plans, VCAP::CloudController::ServicePlansController)
  standard_model_get(:service_plans)
  standard_model_delete(:service_plans)

  post "/v2/service_plans" do
    example "Creating a service plan (deprecated)" do
      client.post "/v2/service_plans", fields_json(service_guid: service_guid), headers
      expect(status).to eq(201)

      standard_entity_response parsed_response, :services
    end
  end

  put "/v2/service_plans" do
    example "Updating a service plan (deprecated)" do
      client.put "/v2/service_plans/#{guid}", fields_json, headers
      expect(status).to eq(201)

      standard_entity_response parsed_response, :services
    end
  end
end
