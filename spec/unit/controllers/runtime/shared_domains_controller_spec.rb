require 'spec_helper'

module VCAP::CloudController
  describe SharedDomainsController do
    describe 'Query Parameters' do
      it { expect(described_class).to be_queryable_by(:name) }
    end

    describe 'Attributes' do
      it do
        expect(described_class).to have_creatable_attributes({
          name: { type: 'string', required: true },
          router_group_guid: { type: 'string', required: false }
        })
      end

      it 'cannot update its fields' do
        expect(described_class).not_to have_updatable_attributes({
          name: { type: 'string' },
          router_group_guid: { type: 'string' }
        })
      end
    end

    context 'router groups' do
      let(:routing_api_client) { double('routing_api_client') }
      before do
        allow(CloudController::DependencyLocator.instance).to receive(:routing_api_client).
          and_return(routing_api_client)
      end

      context 'when router_group_guid is nil' do
        let(:body) do
          {
            name: 'shareddomain.com',
          }.to_json
        end

        it 'does not call the Routing API and UAA' do
          post '/v2/shared_domains', body, json_headers(admin_headers)
          expect(last_response).to have_status_code(201)
        end
      end

      context 'when the router_group_guid exists and is not nil' do
        let(:body) do
          {
            name: 'shareddomain.com',
            router_group_guid: 'router-group-guid1'
          }.to_json
        end

        let(:router_groups) do
          [
            RoutingApi::RouterGroup.new({ 'guid' => 'router-group-guid1' }),
            RoutingApi::RouterGroup.new({ 'guid' => 'random-guid-2' }),
          ]
        end

        before do
          allow(routing_api_client).to receive(:router_groups).and_return(router_groups)
        end

        it 'validates that the router_group_guid is a valid guid for a Router Group' do
          post '/v2/shared_domains', body, json_headers(admin_headers)

          expect(last_response).to have_status_code(201)

          expect(routing_api_client).to have_received(:router_groups).exactly(1).times
          domain = SharedDomain.last
          expect(domain.router_group_guid).to eq 'router-group-guid1'
        end

        context 'when the routing api client raises a UaaUnavailable error' do
          before do
            allow(routing_api_client).to receive(:router_groups).
              and_raise(RoutingApi::Client::UaaUnavailable)
          end

          it 'returns a 503 Service Unavailable' do
            post '/v2/shared_domains', body, json_headers(admin_headers)

            expect(last_response).to have_status_code(503)
            expect(last_response.body).to include 'The UAA service is currently unavailable'
          end
        end

        context 'when the routing api client raises a RoutingApiUnavailable error' do
          before do
            allow(routing_api_client).to receive(:router_groups).
              and_raise(RoutingApi::Client::RoutingApiUnavailable)
          end

          it 'returns a 503 Service Unavailable' do
            post '/v2/shared_domains', body, json_headers(admin_headers)

            expect(last_response).to have_status_code(503)
            expect(last_response.body).to include 'Routing API is currently unavailable'
          end
        end

        context 'when the router_group_guid does not exist in the Routing API' do
          let(:router_groups) { [] }
          it 'returns a 400 error' do
            post '/v2/shared_domains', body, json_headers(admin_headers)

            expect(last_response).to have_status_code(400)
            expect(last_response.body).to include "router group guid 'router-group-guid1' not found"
          end
        end

        # Should not happen, but just in case
        context 'when the router_groups is nil' do
          let(:router_groups) { nil }
          it 'returns a 400 error' do
            post '/v2/shared_domains', body, json_headers(admin_headers)

            expect(last_response).to have_status_code(400)
            expect(last_response.body).to include "router group guid 'router-group-guid1' not found"
          end
        end
      end
    end
  end
end
