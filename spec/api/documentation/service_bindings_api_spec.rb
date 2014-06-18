require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "Service Bindings", :type => :api do
  let(:admin_auth_header) { admin_headers["HTTP_AUTHORIZATION"] }
  let!(:service_binding) { VCAP::CloudController::ServiceBinding.make }
  let(:guid) { service_binding.guid }
  authenticated_request

  get '/v2/service_bindings' do
    standard_model_list :service_bindings, VCAP::CloudController::ServiceBindingsController
  end

  get '/v2/service_bindings/:guid' do
    standard_list_parameters VCAP::CloudController::ServiceBindingsController

    example 'Getting a service binding' do
      client.get "/v2/service_bindings/#{guid}", {}, headers
      expect(status).to eq 200
    end
  end

  post '/v2/service_bindings' do
    field :service_instance_guid, 'The guid of the service instance to bind', required: true
    field :app_guid, 'The guid of the app to bind', required: true
    field :binding_options, 'A hash of options that are passed to v1 brokers', required: false, deprecated: true, optional: true

    example "Create a service binding" do
      space = VCAP::CloudController::Space.make
      service_instance_guid = VCAP::CloudController::ServiceInstance.make(space: space).guid
      app_guid = VCAP::CloudController::App.make(space: space).guid
      request_json = Yajl::Encoder.encode({service_instance_guid: service_instance_guid, app_guid: app_guid}, pretty: true)

      client.post "/v2/service_bindings", request_json, headers
      expect(status).to eq 201
    end
  end

  delete '/v2/service_bindings/:guid' do
    example 'Delete a service binding' do
      client.delete "/v2/service_bindings/#{guid}", {}, headers
      expect(status).to eq 204
    end
  end
end
