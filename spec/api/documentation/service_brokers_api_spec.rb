require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "Service Brokers", :type => :api do
  let(:admin_auth_header) { admin_headers["HTTP_AUTHORIZATION"] }
  let!(:service_brokers) { 3.times { VCAP::CloudController::ServiceBroker.make } }
  let(:service_broker) { VCAP::CloudController::ServiceBroker.first }
  let(:guid) { service_broker.guid }
  let(:broker_catalog) do
    {
      'services' => [
        {
          'id'          => 'custom-service-1',
          'name'        => 'custom-service',
          'description' => 'A description of My Custom Service',
          'bindable'    => true,
          'plans'       => [
            {
              'id'          => 'custom-plan',
              'name'        => 'free',
              'description' => 'Free plan!'
            }
          ]
        }
      ]
    }.to_json
  end

  authenticated_request

  shared_context "guid_parameter" do
    parameter :guid, "The guid of the Service Broker"
  end

  shared_context "updatable_fields" do
    field :name, "The name of the service broker.", required: true, example_values: %w(service-broker-name)
    field :broker_url, "The URL of the service broker.", required: true, example_values: %w(https://broker.example.com)
    field :auth_username, "The username with which to authenticate against the service broker.", required: true, example_values: %w(admin)
    field :auth_password, "The password with which to authenticate against the service broker.", required: true, example_values: %w(secretpassw0rd)
  end

  describe "Standard endpoints" do
    standard_model_list :service_broker, VCAP::CloudController::ServiceBrokersController
    standard_model_get :service_broker
    standard_model_delete :service_broker, async: false

    post "/v2/service_brokers" do
      include_context "updatable_fields"
      before do
        stub_request(:get, "https://admin:secretpassw0rd@broker.example.com:443/v2/catalog").
          with(:headers => {"Accept" => "application/json"}).
          to_return(status: 200, body: broker_catalog, headers: {})
      end

      example "Create a Service Broker" do
        client.post "/v2/service_brokers", fields_json, headers

        expect(status).to eq 201
        validate_response VCAP::RestAPI::MetadataMessage, parsed_response["metadata"]
        expect(parsed_response["entity"]["name"]).to eq("service-broker-name")
        expect(parsed_response["entity"]["broker_url"]).to eq("https://broker.example.com")
        expect(parsed_response["entity"]["auth_username"]).to eq("admin")

        document_warning_header(response_headers)
      end
    end


    put "/v2/service_brokers/:guid" do
      include_context "guid_parameter"
      include_context "updatable_fields"
      before do
        stub_request(:get, "https://admin:secretpassw0rd@broker.example.com:443/v2/catalog").
          with(:headers => {'Accept' => 'application/json'}).
          to_return(status: 200, body: broker_catalog, headers: {})
      end

      example "Update a Service Broker" do
        client.put "/v2/service_brokers/#{guid}", fields_json, headers

        expect(status).to eq 200
        validate_response VCAP::RestAPI::MetadataMessage, parsed_response["metadata"]
        expect(parsed_response["entity"]["broker_url"]).to eq("https://broker.example.com")
        expect(parsed_response["entity"]["name"]).to eq("service-broker-name")
        expect(parsed_response["entity"]["auth_username"]).to eq("admin")

        document_warning_header(response_headers)
      end
    end
  end

  def document_warning_header(response_headers)
    response_headers['X-Cf-Warnings']= 'Warning%3A+Warning+message+may+go+here.'
  end
end
