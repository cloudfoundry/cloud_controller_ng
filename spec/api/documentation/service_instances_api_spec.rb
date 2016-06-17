require 'spec_helper'
require 'rspec_api_documentation/dsl'
require 'uri'

RSpec.resource 'Service Instances', type: [:api, :legacy_api] do
  tags = %w(accounting mongodb)
  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }
  let(:service_broker) { VCAP::CloudController::ServiceBroker.make }
  let(:service) { VCAP::CloudController::Service.make(service_broker: service_broker) }
  let(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service, public: true) }
  let!(:service_instance) do
    service_instance = VCAP::CloudController::ManagedServiceInstance.make(
      service_plan: service_plan, tags: tags)
    service_instance.service_instance_operation = VCAP::CloudController::ServiceInstanceOperation.make(
      state: 'succeeded',
      description: 'service broker-provided description'
    )
    service_instance
  end
  let(:guid) { service_instance.guid }

  authenticated_request

  describe 'Standard endpoints' do
    let(:broker_response_body) do
      {
        last_operation: {
          state: 'in progress'
        }
      }
    end

    before do
      uri = URI(service_broker.broker_url)
      broker_url = uri.host + uri.path
      broker_auth = "#{service_broker.auth_username}:#{service_broker.auth_password}"
      stub_request(:delete,
        %r{https://#{broker_auth}@#{broker_url}/v2/service_instances/#{service_instance.guid}}).
        to_return(status: 202, body: broker_response_body.to_json)
    end

    response_field 'name', 'The human-readable name of the service instance.'
    response_field 'credentials', 'The service broker-provided credentials to use this service.'
    response_field 'service_plan_guid', 'The service plan GUID that this service instance is utilizing.'
    response_field 'space_guid', 'The space GUID that this service instance belongs to.'
    response_field 'gateway_data', '',
      deprecated: true
    response_field 'dashboard_url', 'The service broker-provided URL to access administrative features of the service instance. May be null.'
    response_field 'type', 'The type of service instance.',
      valid_values: ['managed_service_instance', 'user_provided_service_instance']
    response_field 'last_operation', 'The status of the last operation requested on the service instance. May be null.'
    response_field 'last_operation.type', 'The type of operation that was last performed or currently being performed on the service instance',
      valid_values: ['create', 'update', 'delete']
    response_field 'last_operation.state', 'The status of the last operation or current operation being performed on the service instance.',
      valid_values: ['in progress', 'succeeded', 'failed']
    response_field 'last_operation.description', 'The service broker-provided description of the operation. May be null.'
    response_field 'last_operation.updated_at', 'The timestamp that the Cloud Controller last checked the service instance state from the broker.'
    response_field 'space_url', 'The relative path to the space resource that this service instance belongs to.'
    response_field 'service_plan_url', 'The relative path to the service plan resource that this service instance belongs to.'
    response_field 'service_binding_url', 'The relative path to the service bindings that this service instance is bound to.'
    response_field 'routes_url', 'Routes bound to the service instance. Requests to these routes will be forwarded to the service instance.'
    response_field 'tags', 'A list of tags for the service instance'

    standard_model_list :managed_service_instance, VCAP::CloudController::ServiceInstancesController, path: :service_instance
    standard_model_get :managed_service_instance, path: :service_instance, nested_attributes: [:space, :service_plan]

    post '/v2/service_instances/' do
      field :name, 'A name for the service instance', required: true, example_values: ['my-service-instance']
      field :service_plan_guid, 'The guid of the service plan to associate with the instance', required: true
      field :space_guid, 'The guid of the space in which the instance will be created', required: true
      field :parameters, 'Arbitrary parameters to pass along to the service broker. Must be a JSON object', required: false
      field :gateway_data, 'Configuration information for the broker gateway in v1 services', required: false, deprecated: true
      field :tags, 'A list of tags for the service instance. Max characters: 2048',
            required: false, example_values: [%w(db), tags], default: []

      param_description = <<EOF
Set to `true` if the client allows asynchronous provisioning. The cloud controller may respond before the service is ready for use.
EOF
      parameter :accepts_incomplete, param_description, valid_values: [true, false]

      before do
        uri = URI(service_broker.broker_url)
        uri.user = service_broker.auth_username
        uri.password = service_broker.auth_password
        uri.path += '/v2/service_instances/'
        stub_request(:put, /#{uri}.*/).to_return(status: 202, body: broker_response_body.to_json, headers: {})
      end

      example 'Creating a Service Instance' do
        space_guid = VCAP::CloudController::Space.make.guid
        request_hash = {
          space_guid: space_guid,
          name: 'my-service-instance',
          service_plan_guid: service_plan.guid,
          parameters: {
            the_service_broker: 'wants this object'
          },
          tags: tags
        }

        client.post '/v2/service_instances?accepts_incomplete=true', MultiJson.dump(request_hash, pretty: true), headers
        expect(status).to eq(202)
      end
    end

    put '/v2/service_instances/:guid' do
      let(:service_broker) { VCAP::CloudController::ServiceBroker.make }
      let(:service) { VCAP::CloudController::Service.make(service_broker: service_broker, plan_updateable: true) }
      let(:new_plan) { VCAP::CloudController::ServicePlan.make(service: service) }
      let(:old_plan) { VCAP::CloudController::ServicePlan.make(service: service) }
      let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(service_plan: old_plan) }

      field :name, 'The new name for the service instance', required: false, example_values: ['my-new-service-instance']
      field :service_plan_guid, 'The new plan guid for the service instance', required: false, example_values: ['6c4bd80f-4593-41d1-a2c9-b20cb65ec76e']
      field :parameters, 'Arbitrary parameters to pass along to the service broker. Must be a JSON object', required: false
      field :tags, 'A list of tags for the service instance. NOTE: Updating the tags will overwrite any old tags. Max characters: 2048.',
            required: false, example_values: [['db'], ['accounting', 'mongodb']]

      param_description = <<EOF
Set to `true` if the client allows asynchronous provisioning. The cloud controller may respond before the service is ready for use.
EOF
      parameter :accepts_incomplete, param_description, valid_values: [true, false]

      before do
        uri = URI(service_broker.broker_url)
        uri.user = service_broker.auth_username
        uri.password = service_broker.auth_password
        uri.path += "/v2/service_instances/#{service_instance.guid}"
        uri.query = 'accepts_incomplete=true'
        stub_request(:patch, uri.to_s).to_return(status: 202, body: broker_response_body.to_json, headers: {})
      end

      example 'Update a Service Instance' do
        request_json = {
          service_plan_guid: new_plan.guid,
          parameters: {
            the_service_broker: 'wants this object'
          }
        }.to_json
        client.put "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", request_json, headers

        expect(status).to eq 202
        expect(service_instance.reload.last_operation.state).to eq 'in progress'
        expect(service_instance.reload.service_plan.guid).to eq old_plan.guid
      end
    end

    delete '/v2/service_instances/:guid' do
      accepts_incomplete_description = <<EOF
Set to `true` if the client allows asynchronous provisioning. The cloud controller may respond before the service is ready for use.
EOF
      purge_description = <<EOF
Recursively remove a service instance and child objects from Cloud Foundry database without making requests to a service broker.
The user must have the cloud_controller.admin scope on their OAuth token in order to perform a purge.
EOF
      recursive_description = <<EOF
Will delete service bindings, service keys, and routes associated with the service instance.
EOF
      async_description = <<EOF
Will run the delete request in a background job. Recommended: 'true'.
EOF

      parameter :accepts_incomplete, accepts_incomplete_description, valid_values: [true, false]
      parameter :purge, purge_description, valid_values: [true, false]
      parameter :recursive, recursive_description, valid_values: [true, false]
      parameter :async, async_description, valid_values: [true, false]

      before do
        uri = URI(service_broker.broker_url)
        uri.user = service_broker.auth_username
        uri.password = service_broker.auth_password
        uri.path += "/v2/service_instances/#{service_instance.guid}"
        stub_request(:delete, /#{uri}?.*/).to_return(status: 202, body: broker_response_body.to_json, headers: {})
      end

      example 'Delete a Service Instance' do
        client.delete "/v2/service_instances/#{service_instance.guid}?accepts_incomplete=true", {}, headers

        expect(status).to eq 202
        after_standard_model_delete(guid) if respond_to?(:after_standard_model_delete)
      end
    end
  end

  describe 'Nested endpoints' do
    describe 'Service Bindings' do
      before do
        VCAP::CloudController::ServiceBinding.make(service_instance: service_instance)
      end

      standard_model_list :service_binding, VCAP::CloudController::ServiceBindingsController, outer_model: :service_instance
    end

    describe 'Routes' do
      let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(:routing) }
      let(:route) { VCAP::CloudController::Route.make(space: service_instance.space) }
      let!(:route_binding) { VCAP::CloudController::RouteBinding.make(service_instance: service_instance) }

      put '/v2/service_instances/:service_instance_guid/routes/:route_guid' do
        before do
          stub_bind(service_instance)
        end

        field :parameters, 'Arbitrary parameters to pass along to the service broker. Must be a JSON object.', required: false

        example 'Binding a Service Instance to a Route' do
          request_hash = {
              parameters: {
                  the_service_broker: 'wants this object'
              }
          }

          client.put "/v2/service_instances/#{service_instance.guid}/routes/#{route.guid}", MultiJson.dump(request_hash, pretty: true), headers

          expect(status).to eq(201)
          expect(parsed_response['metadata']['guid']).to eq(service_instance.guid)
          expect(parsed_response['entity']['routes_url']).to eq("/v2/service_instances/#{service_instance.guid}/routes")
          audited_event VCAP::CloudController::Event.find(type: 'audit.service_instance.bind_route', actee: service_instance.guid)
        end
      end

      delete '/v2/service_instances/:service_instance_guid/routes/:route_guid' do
        before do
          binding = VCAP::CloudController::RouteBinding.make(service_instance: service_instance, route: route)
          stub_unbind(binding)
        end

        example 'Unbinding a service instance from a route' do
          client.delete "/v2/service_instances/#{service_instance.guid}/routes/#{route.guid}", {}, headers
          expect(status).to eq(204)
          expect(response_body).to be_empty
          audited_event VCAP::CloudController::Event.find(type: 'audit.service_instance.unbind_route', actee: service_instance.guid)
        end
      end

      standard_model_list :route, VCAP::CloudController::RoutesController, outer_model: :service_instance
    end

    describe 'Service Keys' do
      before do
        VCAP::CloudController::ServiceKey.make(name: 'a-service-key', service_instance: service_instance)
      end

      standard_model_list :service_key, VCAP::CloudController::ServiceInstancesController, outer_model: :service_instance
    end
  end

  get '/v2/service_instances/:guid/permissions' do
    example 'Retrieving permissions on a Service Instance' do
      client.get "/v2/service_instances/#{service_instance.guid}/permissions", {}, headers
      expect(status).to eq(200)

      expect(parsed_response).to eql({ 'manage' => true })
    end
  end
end
