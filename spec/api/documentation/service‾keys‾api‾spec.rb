require 'spec_helper'
require 'rspec_api_documentation/dsl'

RSpec.resource 'Service Keys', type: [:api, :legacy_api] do
  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }
  let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make }
  let(:service_key) { VCAP::CloudController::ServiceKey.make }
  let(:guid) { service_key.guid }
  authenticated_request

  before do
    create_response_body = { 'credentials' => service_instance.credentials }
    stub_bind(service_instance, body: create_response_body.to_json)
    stub_unbind(service_key)
  end

  standard_model_list :service_key, VCAP::CloudController::ServiceKeysController
  standard_model_get :service_key, nested_associations: [:service_instance]
  standard_model_delete :service_key, async: false

  post '/v2/service_keys' do
    field :service_instance_guid, 'The guid of the service instance for which to create service key', required: true
    field :name, 'The name of the service key', required: true
    field :parameters, 'Arbitrary parameters to pass along to the service broker. Must be a JSON object', required: false

    example 'Create a Service Key' do
      request_json = MultiJson.dump({ service_instance_guid: service_instance.guid, name: service_key.name }, pretty: true)
      client.post('/v2/service_keys', request_json, headers).inspect
      expect(status).to eq 201
    end
  end
end
