require 'spec_helper'
require 'rspec_api_documentation/dsl'

RSpec.resource 'Service Bindings', type: [:api, :legacy_api] do
  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }
  let!(:service_binding) { VCAP::CloudController::ServiceBinding.make }
  let!(:v2_app) { VCAP::CloudController::ProcessModel.make(app: service_binding.app, type: 'web') }
  let(:guid) { service_binding.guid }
  authenticated_request

  before do
    service_broker = service_binding.service.service_broker
    service_instance = service_binding.service_instance
    uri = URI(service_broker.broker_url)
    broker_url = uri.host + uri.path
    broker_auth = "#{service_broker.auth_username}:#{service_broker.auth_password}"
    stub_request(
      :delete,
      %r{https://#{broker_auth}@#{broker_url}/v2/service_instances/#{service_instance.guid}/service_bindings/#{service_binding.guid}}).
      to_return(status: 200, body: '{}')
  end

  standard_model_list :service_binding,
    VCAP::CloudController::ServiceBindingsController,
    export_attributes: [:app_guid, :service_instance_guid, :credentials, :binding_options, :gateway_data, :gateway_name, :syslog_drain_url, :volume_mounts]
  standard_model_get :service_binding,
    nested_associations: [:app, :service_instance],
    export_attributes: [:app_guid, :service_instance_guid, :credentials, :binding_options, :gateway_data, :gateway_name, :syslog_drain_url, :volume_mounts]
  standard_model_delete :service_binding

  post '/v2/service_bindings' do
    field :service_instance_guid, 'The guid of the service instance to bind', required: true
    field :app_guid, 'The guid of the app to bind', required: true
    field :binding_options, 'A hash of options that are passed to v1 brokers', required: false, deprecated: true, optional: true
    field :parameters, 'Arbitrary parameters to pass along to the service broker. Must be a JSON object', required: false

    example 'Create a Service Binding' do
      space = VCAP::CloudController::Space.make
      service_instance_guid = VCAP::CloudController::ServiceInstance.make(space: space).guid
      process_guid = VCAP::CloudController::AppFactory.make(space: space).guid
      request_json = MultiJson.dump({ service_instance_guid: service_instance_guid, app_guid: process_guid, parameters: { the_service_broker: 'wants this object' } }, pretty: true)

      client.post '/v2/service_bindings', request_json, headers
      expect(status).to eq 201
    end
  end
end
