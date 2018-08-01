require 'spec_helper'

module VCAP::CloudController::RoutingApi
  RSpec.describe Client do
    let(:uaa_client) { instance_double(VCAP::CloudController::UaaClient, token_info: token_info) }
    let(:token_info) { instance_double(CF::UAA::TokenInfo, auth_header: 'bearer my-token') }
    let(:routing_api_url) { 'http://routing-api.example.com' }
    let(:skip_cert_verify) { false }
    let(:body) { nil }
    let(:status) { 400 }
    let(:path) { '/routing/v1/router_groups' }
    let(:routing_api) { Client.new(routing_api_url, uaa_client, skip_cert_verify) }

    before do
      if !routing_api_url.nil?
        uri = URI(routing_api_url)
        uri.path = path
        stub_request(:get, uri.to_s).
          to_return(status: status, body: body)
      end
    end

    describe '.enabled?' do
      it 'returns true' do
        expect(routing_api.enabled?).to be_truthy
      end
    end

    describe '.router_groups' do
      let(:status) { 200 }
      let(:body) do
        [
          { guid: 'random-guid-1', name: 'group-name', type: 'tcp' },
          { guid: 'random-guid-2', name: 'group-name', type: 'tcp' },
        ].to_json
      end

      context 'when the routing api url does not exist' do
        let(:routing_api_url) { nil }
        it 'raises a RoutingApiUnavailable error' do
          expect {
            routing_api.router_groups
          }.to raise_error RoutingApiUnavailable
        end
      end

      context 'when the routing api url does exist' do
        it 'calls the routing-api and retrieves a list of known router groups' do
          expected_router_group1 = RouterGroup.new('guid' => 'random-guid-1')
          expected_router_group2 = RouterGroup.new('guid' => 'random-guid-2')
          response = routing_api.router_groups
          expect(response).to eq [expected_router_group1, expected_router_group2]

          expect(a_request(:get, routing_api_url + path)).
            to have_been_made.times(1)
        end

        it 'sends an authorization token with the request' do
          routing_api.router_groups

          expect(a_request(:get, routing_api_url + path).
                     with(headers: { 'Authorization' => 'bearer my-token' })).
            to have_been_made.times(1)
        end

        it 'does not set the HTTPClient::SSLConfig' do
          expect_any_instance_of(HTTPClient::SSLConfig).to_not receive(:verify_mode=).with(OpenSSL::SSL::VERIFY_PEER)
          routing_api.router_groups
        end

        context 'when fetching a token' do
          context 'and uaa_client raises a CF::UAA::BadResponse error' do
            before do
              allow(uaa_client).to receive(:token_info).and_raise(CF::UAA::BadResponse)
            end

            it 'raises a UaaUnavailable' do
              expect {
                routing_api.router_groups
              }.to raise_error UaaUnavailable

              expect(a_request(:get, routing_api_url + path)).
                to have_been_made.times(0)
            end
          end
        end

        context 'when routing api returns an error' do
          before do
            uri = URI(routing_api_url)
            uri.path = path

            stub_request(:get, uri.to_s).
              to_return(status: 500, body: '')
          end

          it 'raises a error' do
            expect {
              routing_api.router_groups
            }.to raise_error RoutingApiUnavailable

            expect(a_request(:get, routing_api_url + path)).
              to have_been_made.times(1)
          end
        end

        context 'when the routing-api url is an HTTPS url' do
          let(:routing_api_url) { 'https://routing-api.example.com' }

          context 'when skip_cert_verify is true' do
            let(:skip_cert_verify) { true }

            it 'establishes a HTTPS connection without validating peer certificate' do
              expect_any_instance_of(HTTPClient::SSLConfig).to receive(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)
              routing_api.router_groups
            end
          end

          context 'when skip_cert_verify is false' do
            let(:skip_cert_verify) { false }

            it 'establishes a HTTPS connection and validates the peer certificate' do
              expect_any_instance_of(HTTPClient::SSLConfig).to receive(:verify_mode=).with(OpenSSL::SSL::VERIFY_PEER)
              routing_api.router_groups
            end
          end
        end

        context 'when the response from the routing api generates a JSON parse error' do
          before do
            uri = URI(routing_api_url)
            uri.path = path

            stub_request(:get, uri.to_s).
              to_return(status: 200, body: '{\/adf[{')
          end

          it 'returns a RoutingApiUnavailable error' do
            expect {
              routing_api.router_groups
            }.to raise_error RoutingApiUnavailable

            expect(a_request(:get, routing_api_url + path)).
              to have_been_made.times(1)
          end
        end
      end
    end

    describe '.router_group' do
      let(:status) { 200 }
      let(:body) do
        [
          { guid: 'random-guid-1', name: 'group-name', type: 'tcp' },
          { guid: 'router-group-guid', name: 'group-name', type: 'my-type' },
        ].to_json
      end

      context 'when the guid exists' do
        let(:guid) { 'router-group-guid' }
        let(:type) { 'my-type' }

        it 'returns the router group object' do
          group = routing_api.router_group(guid)
          expect(group.guid).to eq(guid)
          expect(group.type).to eq(type)
        end
      end

      context 'when the guid does not exist' do
        it 'return nil' do
          group = routing_api.router_group('no-group-guid')
          expect(group).to be_nil
        end
      end
    end

    describe '.router_group_guid' do
      let(:status) { 200 }
      let(:body) do
        [
          { guid: 'random-guid-1', name: 'group-name', type: 'tcp' },
          { guid: 'router-group-guid', name: 'group-name-2', type: 'my-type' },
        ].to_json
      end

      it 'provides the associated router name for the given guid' do
        expect(routing_api.router_group_guid('group-name')).to eq('random-guid-1')
      end

      context 'when there is no router group guid for the given name' do
        it 'returns nil' do
          expect(routing_api.router_group_guid('some-random-guid')).to be_nil
        end
      end
    end
  end
end
