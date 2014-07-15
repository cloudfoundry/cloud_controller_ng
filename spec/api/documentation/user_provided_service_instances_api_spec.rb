require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "User Provided Service Instances", :type => :api do
  let(:admin_auth_header) { admin_headers["HTTP_AUTHORIZATION"] }
  let!(:service_instance) { VCAP::CloudController::UserProvidedServiceInstance.make }
  let(:guid) { service_instance.guid }

  authenticated_request

  describe "Standard endpoints" do
    standard_model_list :user_provided_service_instance, VCAP::CloudController::UserProvidedServiceInstancesController
    standard_model_get :user_provided_service_instance, nested_attributes: [:space]
    standard_model_delete_without_async :user_provided_service_instance

    post '/v2/user_provided_service_instances/' do
      field :name, 'A name for the service instance', required: true, example_values: [ 'my-user-provided-instance' ]
      field :space_guid, 'The guid of the space in which the instance will be created', required: true
      field :syslog_drain_url, 'The url for the syslog_drain to direct to', required: false, example_values: [ 'syslog://example.com' ]
      field :credentials, 'A hash that can be used to store credentials', required: false, example_values: [ { somekey: 'somevalue' }.to_s ]

      example 'Creating a User Provided Service Instance' do
        space_guid = VCAP::CloudController::Space.make.guid
        request_hash = {
          space_guid: space_guid,
          name: 'my-user-provided-instance',
          credentials: {somekey: 'somevalue'},
          syslog_drain_url: 'syslog://example.com'
        }

        client.post '/v2/user_provided_service_instances', MultiJson.dump(request_hash, pretty: true), headers
        expect(status).to eq(201)
      end
    end

    put '/v2/user_provided_service_instances/:guid' do
      field :name, 'A name for the service instance', required: true, example_values: [ 'my-user-provided-instance' ]
      field :syslog_drain_url, 'The url for the syslog_drain to direct to', required: false, example_values: [ 'syslog://example.com' ]
      field :credentials, 'A hash that can be used to store credentials', required: false, example_values: [ { somekey: 'somevalue' }.to_s ]

      example 'Updating a User Provided Service Instance' do
        request_hash = {
          credentials: {somekey: 'somenewvalue'}
        }

        client.put "/v2/user_provided_service_instances/#{guid}", MultiJson.dump(request_hash, pretty: true), headers
        expect(status).to eq(201)
        standard_entity_response parsed_response, :user_provided_service_instance, credentials: {'somekey' => 'somenewvalue'}
      end
    end
  end

  describe "Nested endpoints" do
    field :guid, "The guid of the Service Instance.", required: true

    describe "Service Bindings" do
      before do
        VCAP::CloudController::ServiceBinding.make(service_instance: service_instance)
      end

      standard_model_list :service_binding, VCAP::CloudController::ServiceBindingsController, outer_model: :user_provided_service_instance
    end
  end
end
