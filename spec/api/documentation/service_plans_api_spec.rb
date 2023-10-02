require 'spec_helper'
require 'rspec_api_documentation/dsl'

RSpec.resource 'Service Plans', type: %i[api legacy_api] do
  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }
  let!(:service_plan) { VCAP::CloudController::ServicePlan.make }
  let(:guid) { service_plan.guid }
  authenticated_request

  describe 'Standard endpoints' do
    field :guid, 'The guid of the service plan', required: false
    field :public, 'A boolean describing that the plan is visible to the all users', required: false, default: true

    expected_attributes = VCAP::CloudController::ServicePlan.new.export_attrs - [:create_instance_schema] - [:update_instance_schema] - [:create_binding_schema] + [:schemas]

    standard_model_list(:service_plans, VCAP::CloudController::ServicePlansController, export_attributes: expected_attributes)
    standard_model_get(:service_plans, export_attributes: expected_attributes)
    standard_model_delete(:service_plans)

    put '/v2/service_plans' do
      example 'Updating a Service Plan' do
        client.put "/v2/service_plans/#{guid}", fields_json(public: false), headers
        expect(status).to eq(201)

        standard_entity_response parsed_response, :service_plans, expected_attributes:
      end
    end
  end

  describe 'Nested endpoints' do
    field :guid, 'The guid of the Service Plan.', required: true

    describe 'Service Instances' do
      before do
        VCAP::CloudController::ManagedServiceInstance.make(service_plan:)
      end

      standard_model_list :managed_service_instance,
                          VCAP::CloudController::ServiceInstancesController,
                          outer_model: :service_plan,
                          path: :service_instances,
                          exclude_parameters: %w[organization_guid service_plan_guid]
    end
  end
end
