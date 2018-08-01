require 'spec_helper'

RSpec.describe 'Service Broker API integration' do
  describe 'v2.8' do
    include VCAP::CloudController::BrokerApiHelper
    let(:route) { VCAP::CloudController::Route.make(space: @space) }
    let(:catalog) { default_catalog(requires: ['route_forwarding']) }
    let(:service_broker_bind_request) { %r{.*/v2/service_instances/#{@service_instance_guid}/service_bindings/#{guid_pattern}} }

    before do
      setup_cc
      setup_broker(catalog)
      create_app
      provision_service
    end

    after do
      delete_broker
    end

    describe 'route forwarding for service instances' do
      context 'when the broker does not return a route service url' do
        before do
          stub_request(:put, service_broker_bind_request).
            to_return(status: 201, body: '{}')
        end

        it 'cc responds with success' do
          put("/v2/service_instances/#{@service_instance_guid}/routes/#{route.guid}", {}.to_json, json_headers(admin_headers))

          expect(last_response.status).to eq 201
          expect(a_request(:put, service_broker_bind_request)).to have_been_made
        end
      end

      context 'when the broker returns a route service url' do
        let(:service_broker_client) { instance_double(VCAP::Services::ServiceBrokers::V2::HttpClient) }

        before do
          stub_request(:put, service_broker_bind_request).
            to_return(status: 201, body: { 'route_service_url' => 'https://neopets.com' }.to_json)
        end

        it 'cc proxies the bind request' do
          put("/v2/service_instances/#{@service_instance_guid}/routes/#{route.guid}", {}.to_json, json_headers(admin_headers))

          route_binding = VCAP::CloudController::RouteBinding.last
          expect(route_binding.route_service_url).to eq('https://neopets.com')
        end
      end
    end
  end
end
