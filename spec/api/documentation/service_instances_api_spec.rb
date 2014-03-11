require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "Service Instances", :type => :api do
  let(:admin_auth_header) { headers_for(admin_user, :admin_scope => true)["HTTP_AUTHORIZATION"] }
  let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make }

  authenticated_request

  get "/v2/service_instances/:guid/permissions" do
    field :guid, "The guid of the service instance", required: true, example_values: %w(6c4bd80f-4593-41d1-a2c9-b20cb65ec76e)

    example "Retrieving permissions on a service instance" do
      client.get "/v2/service_instances/#{service_instance.guid}/permissions", {}, headers
      expect(status).to eq(200)

      expect(parsed_response).to eql({'manage' => true})
    end
  end

  put '/v2/service_plans/:service_plan_guid/service_instances' do
    let(:new_plan) { VCAP::CloudController::ServicePlan.make }
    let(:old_plan) { service_instance.service_plan }
    let(:request_json) { {service_plan_guid: new_plan.guid}.to_json }

    field :service_plan_guid, "The guid of the plan to move the existing instances to", required: true, example_values: %w(6c4bd80f-4593-41d1-a2c9-b20cb65ec76e)

    example 'Migrate instances from one plan to another plan (experimental)' do
      explanation <<-EOD
          Move all service instances for the service plan from the URL to the service plan in the request body
      EOD

      client.put "/v2/service_plans/#{old_plan.guid}/service_instances", request_json, headers

      expect(status).to eq(200)
      expect(parsed_response['changed_count']).to eq(1)
    end
  end
end
