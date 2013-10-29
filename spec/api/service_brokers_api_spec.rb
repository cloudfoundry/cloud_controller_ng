require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "Service Brokers", :type => :api do
  let(:admin_auth_header) { headers_for(admin_user, :admin_scope => true)["HTTP_AUTHORIZATION"] }
  authenticated_request

  before do
    3.times { VCAP::CloudController::ServiceBroker.make }
  end

  let(:service_broker) { VCAP::CloudController::ServiceBroker.first }
  let(:guid) { service_broker.guid }
  let (:broker_catalog) do
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

  field :name, "The name of the service broker.", required: false, example_values: 'service-broker-name'
  field :broker_url, "The URL of the service broker.", required: false, example_values: 'https://broker.example.com'
  field :auth_username, "The username with which to authenticate against the service broker.", required: false, example_values: 'admin'
  field :auth_password, "The password with which to authenticate against the service broker.", required: false, example_values: 'secretpassw0rd'

  #enumerate
  get "/v2/service_brokers" do
    request_parameter :q, "Parameters used to filter the result set. Valid filters: 'name'"

    example "List all service brokers" do
      client.get "/v2/service_brokers", {}, headers
      json            = parsed_response
      service_brokers = json["resources"]

      status.should == 200
      validate_response VCAP::RestAPI::PaginatedResponse, json
      expect(service_brokers).to have(3).entries
      service_brokers.each do |broker|
        validate_response VCAP::RestAPI::MetadataMessage, broker["metadata"]
        expect(broker["entity"].keys).to include("name", "broker_url", "auth_username")
      end
    end
  end

  post "/v2/service_brokers" do
    before do
      stub_request(:get, "http://#{auth_username}:#{auth_password}@broker.example.com:443/v2/catalog").
        with(:headers => {'Accept' => 'application/json', 'Content-Type' => 'application/json'}).
        to_return(:status => 200, :body => broker_catalog, :headers => {})
    end

    let(:name) { 'service-broker-name' }
    let(:broker_url) { 'https://broker.example.com' }
    let(:auth_username) { 'admin' }
    let(:auth_password) { 'secretpassw0rd' }

    example "Create a service broker" do
      client.post(
        "/v2/service_brokers",
        Yajl::Encoder.encode(
          {
            :name          => name,
            :broker_url    => broker_url,
            :auth_username => auth_username,
            :auth_password => auth_password
          }),
        headers)

      json = parsed_response

      status.should == 201
      validate_response VCAP::RestAPI::MetadataMessage, json["metadata"]
      expect(json["entity"]["name"]).to eq(name)
      expect(json["entity"]["broker_url"]).to eq(broker_url)
      expect(json["entity"]["auth_username"]).to eq(auth_username)
    end
  end

  delete "/v2/service_brokers/:guid" do
    request_parameter :guid, "The guid of the service broker being deleted."

    example "Delete a service broker" do
      client.delete "/v2/service_brokers/#{guid}", {}, headers
      status.should == 204
    end
  end

  put "/v2/service_brokers/:guid" do
    before do
      stub_request(:get, "http://#{user}:#{password}@updated-broker.example.com:443/v2/catalog").
        with(:headers => {'Accept' => 'application/json', 'Content-Type' => 'application/json'}).
        to_return(:status => 200, :body => broker_catalog, :headers => {})
    end

    let(:user) { service_broker.auth_username }
    let(:password) { service_broker.auth_password }
    let(:broker_url) { "https://updated-broker.example.com" }

    request_parameter :guid, "The guid of the service broker being updated."

    example "Update a service broker's URL" do
      client.put(
        "/v2/service_brokers/#{guid}",
        Yajl::Encoder.encode({ :broker_url => broker_url }),
        headers)

      json = parsed_response

      status.should == 200
      validate_response VCAP::RestAPI::MetadataMessage, json["metadata"]
      expect(json["entity"]["broker_url"]).to eq(broker_url)
    end
  end
end
