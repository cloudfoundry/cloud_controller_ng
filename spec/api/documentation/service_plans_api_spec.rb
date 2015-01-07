require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource 'Service Plans', type: [:api, :legacy_api] do
  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }
  let(:service) { VCAP::CloudController::Service.make }
  let(:service_guid) { service.guid }
  let!(:service_plan) { VCAP::CloudController::ServicePlan.make(service_guid: service_guid) }
  let(:guid) { service_plan.guid }
  authenticated_request

  describe 'Standard endpoints' do
    field :guid, 'The guid of the service plan', required: false
    field :name, 'The name of the service plan', required: true, example_values: ['100mb']
    field :free, 'A boolean describing if the service plan is free', required: true, valid_values: [true, false]
    field :description, 'A description of the service plan', required: true, example_values: ["Let's you put data in your database!"]
    field :extra, 'A JSON string with additional data about the plan', required: false, default: nil, example_values: ['{"cost": "$2.00"}']
    field :unique_id, 'A guid for the service plan in the service broker (not the same as the cloud controller guid)', required: false, default: nil
    field :public, 'A boolean describing that the plan is visible to the all users', required: false, default: true
    field :service_guid, 'The guid of the related service', required: true, example_values: ['deadbeef']
    field :active, 'A boolean that determines whether plans can be used to create new instances.', required: false, readonly: true, valid_values: [true, false]

    standard_model_list(:service_plans, VCAP::CloudController::ServicePlansController)
    standard_model_get(:service_plans, nested_attributes: [:service])
    standard_model_delete(:service_plans)

    post '/v2/service_plans' do
      example 'Creating a Service Plan (deprecated)' do
        client.post '/v2/service_plans', fields_json(service_guid: service_guid), headers
        expect(status).to eq(201)

        standard_entity_response parsed_response, :service_plans
      end
    end

    put '/v2/service_plans' do
      example 'Updating a Service Plan (deprecated)' do
        client.put "/v2/service_plans/#{guid}", fields_json(service_guid: service_guid), headers
        expect(status).to eq(201)

        standard_entity_response parsed_response, :service_plans
      end
    end
  end

  describe 'Nested endpoints' do
    field :guid, 'The guid of the Service Plan.', required: true

    describe 'Service Instances' do
      before do
        VCAP::CloudController::ManagedServiceInstance.make(service_plan: service_plan)
      end

      standard_model_list :managed_service_instance,
                          VCAP::CloudController::ServiceInstancesController,
                          outer_model: :service_plan,
                          path: :service_instances
    end
  end
end
