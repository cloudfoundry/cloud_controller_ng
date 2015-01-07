require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource 'Service Plan Visibilities', type: [:api, :legacy_api] do
  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }
  let!(:service_plan_visibility) { VCAP::CloudController::ServicePlanVisibility.make }
  let(:guid) { service_plan_visibility.guid }
  authenticated_request

  standard_model_list(:service_plan_visibilities, VCAP::CloudController::ServicePlanVisibilitiesController)
  standard_model_get(:service_plan_visibilities, nested_attributes: [:service_plan, :organization])
  standard_model_delete(:service_plan_visibilities)

  post '/v2/service_plan_visibilities' do
    field :service_plan_guid, 'The guid of the plan that will be made visible', required: true
    field :organization_guid, 'The guid of the organization the plan will be visible to', required: true

    example 'Creating a Service Plan Visibility' do
      org_guid = VCAP::CloudController::Organization.make.guid
      service_plan_guid = VCAP::CloudController::ServicePlan.make.guid
      request_json = MultiJson.dump({ service_plan_guid: service_plan_guid, organization_guid: org_guid }, pretty: true)

      client.post '/v2/service_plan_visibilities', request_json, headers
      expect(status).to eq(201)
    end
  end

  put '/v2/service_plan_visibilities/:guid' do
    field :service_plan_guid, 'The guid of the plan that will be made visible', required: true
    field :organization_guid, 'The guid of the organization the plan will be visible to', required: true

    example 'Updating a Service Plan Visibility' do
      service_plan_visibility_guid = VCAP::CloudController::ServicePlanVisibility.make.guid
      org_guid = VCAP::CloudController::Organization.make.guid
      service_plan_guid = VCAP::CloudController::ServicePlan.make.guid
      request_json = MultiJson.dump({ service_plan_guid: service_plan_guid, organization_guid: org_guid }, pretty: true)

      client.put "/v2/service_plan_visibilities/#{service_plan_visibility_guid}", request_json, headers
      expect(status).to eq(201)
    end
  end
end
