require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "Service Instances", :type => :api do
  authenticated_request
  let(:admin_auth_header) { headers_for(admin_user, :admin_scope => true)["HTTP_AUTHORIZATION"] }
  let!(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make }

  describe 'Listing all service instances' do
    standard_model_list :service_instance, VCAP::CloudController::ServiceInstancesController
  end

  post '/v2/service_instances/' do
    field :name, 'A name for the service instance', required: true, example_values: [ 'my-service-instance' ]
    field :service_plan_guid, 'The guid of the service plan to associate with the instance', required: true
    field :space_guid, 'The guid of the space in which the instance will be created', required: true
    field :gateway_data, 'Configuration information for the broker gateway in v1 services', required: false, deprecated: true

    example 'Creating a service instance' do
      space_guid = VCAP::CloudController::Space.make.guid
      service_plan_guid = VCAP::CloudController::ServicePlan.make(public: true).guid
      request_hash = {space_guid: space_guid, name: 'my-service-instance', service_plan_guid: service_plan_guid }

      client.post '/v2/service_instances', Yajl::Encoder.encode(request_hash, pretty: true), headers
      expect(status).to eq(201)
    end
  end

  describe 'Deleting a service instance' do
    let(:guid) { VCAP::CloudController::ServiceInstance.make.guid }

    standard_model_delete_without_async :service_instance
  end

  describe 'Getting a service instance' do
    standard_list_parameters VCAP::CloudController::ServiceInstancesController
    let(:guid) { VCAP::CloudController::ServiceInstance.make.guid }

    standard_model_get :service_instance
  end

  get "/v2/service_instances/:guid/permissions" do
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

  post '/v2/user_provided_service_instances/' do
    field :name, 'A name for the service instance', required: true, example_values: [ 'my-user-provided-instance' ]
    field :space_guid, 'The guid of the space in which the instance will be created', required: true
    field :syslog_drain_url, 'The url for the syslog_drain to direct to', required: false, example_values: [ 'syslog://example.com' ]
    field :credentials, 'A hash that can be used to store credentials', required: false, example_values: [ { somekey: 'somevalue' }.to_s ]

    example 'Creating a user provided service instance' do
      space_guid = VCAP::CloudController::Space.make.guid
      request_hash = {
        space_guid: space_guid,
        name: 'my-user-provided-instance',
        credentials: {somekey: 'somevalue'},
        syslog_drain_url: 'syslog://example.com'
      }

      client.post '/v2/user_provided_service_instances', Yajl::Encoder.encode(request_hash, pretty: true), headers
      expect(status).to eq(201)
    end
  end
end
