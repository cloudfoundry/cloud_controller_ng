require 'spec_helper'
require 'request_spec_shared_examples'
require_relative 'shared_context'

# Split from spec/request/routes_spec.rb for better test parallelization

RSpec.describe 'Routes Request' do
  include_context 'routes request spec'

  describe 'GET /v3/apps/:app_guid/routes' do
    let(:app_model) { VCAP::CloudController::AppModel.make(space:) }
    let(:route1) { VCAP::CloudController::Route.make(space:) }
    let(:route2) { VCAP::CloudController::Route.make(space:) }
    let!(:route3) { VCAP::CloudController::Route.make(space:) }
    let!(:route_mapping1) { VCAP::CloudController::RouteMappingModel.make(app: app_model, route: route1, process_type: 'web') }
    let!(:route_mapping2) { VCAP::CloudController::RouteMappingModel.make(app: app_model, route: route2, process_type: 'admin') }
    let(:api_call) { ->(user_headers) { get "/v3/apps/#{app_model.guid}/routes", nil, user_headers } }

    let(:route1_json) do
      {
        guid: route1.guid,
        protocol: route1.domain.protocols[0],
        host: route1.host,
        path: route1.path,
        port: nil,
        url: "#{route1.host}.#{route1.domain.name}#{route1.path}",
        created_at: iso8601,
        updated_at: iso8601,
        destinations: contain_exactly({
                                        guid: route_mapping1.guid,
                                        app: {
                                          guid: app_model.guid,
                                          process: {
                                            type: route_mapping1.process_type
                                          }
                                        },
                                        weight: route_mapping1.weight,
                                        port: route_mapping1.presented_port,
                                        protocol: 'http1',
                                        created_at: iso8601,
                                        updated_at: iso8601
                                      }),
        relationships: {
          space: {
            data: { guid: route1.space.guid }
          },
          domain: {
            data: { guid: route1.domain.guid }
          }
        },
        metadata: {
          labels: {},
          annotations: {}
        },
        links: {
          self: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{route1.guid}} },
          space: { href: %r{#{Regexp.escape(link_prefix)}/v3/spaces/#{route1.space.guid}} },
          destinations: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{route1.guid}/destinations} },
          domain: { href: %r{#{Regexp.escape(link_prefix)}/v3/domains/#{route1.domain.guid}} }
        },
        options: {}
      }
    end

    let(:route2_json) do
      {
        guid: route2.guid,
        protocol: route2.domain.protocols[0],
        host: route2.host,
        path: route2.path,
        port: nil,
        url: "#{route2.host}.#{route2.domain.name}#{route2.path}",
        created_at: iso8601,
        updated_at: iso8601,
        destinations: contain_exactly({
                                        guid: route_mapping2.guid,
                                        app: {
                                          guid: app_model.guid,
                                          process: {
                                            type: route_mapping2.process_type
                                          }
                                        },
                                        weight: route_mapping2.weight,
                                        port: route_mapping2.presented_port,
                                        protocol: 'http1',
                                        created_at: iso8601,
                                        updated_at: iso8601
                                      }),
        relationships: {
          space: {
            data: { guid: route2.space.guid }
          },
          domain: {
            data: { guid: route2.domain.guid }
          }
        },
        metadata: {
          labels: {},
          annotations: {}
        },
        links: {
          self: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{route2.guid}} },
          space: { href: %r{#{Regexp.escape(link_prefix)}/v3/spaces/#{route2.space.guid}} },
          destinations: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{route2.guid}/destinations} },
          domain: { href: %r{#{Regexp.escape(link_prefix)}/v3/domains/#{route2.domain.guid}} }
        },
        options: {}
      }
    end

    context 'when the user is a member in the app space' do
      let(:expected_codes_and_responses) do
        h = Hash.new(
          { code: 200,
            response_objects: [route1_json, route2_json] }.freeze
        )

        h['org_auditor'] = { code: 404 }
        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
        h
      end

      it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
    end

    context 'ports filter' do
      # Don't even think of converting the following hash to symbols ('type' => 'tcp' NOT type: 'tcp'), and you need to set the GUID
      let(:router_group) { VCAP::CloudController::RoutingApi::RouterGroup.new({ 'type' => 'tcp', 'reservable_ports' => '7777,8888,9999', 'guid' => 'some-guid' }) }
      let(:routing_api_client) { instance_double(VCAP::CloudController::RoutingApi::Client) }

      before do
        allow_any_instance_of(CloudController::DependencyLocator).to receive(:routing_api_client).and_return(routing_api_client)
        allow(routing_api_client).to receive_messages(enabled?: true, router_group: router_group)
      end

      context 'when there are multiple TCP routes with different ports' do
        # The following `let`s depend on the above `before do`
        let(:domain_tcp) { VCAP::CloudController::SharedDomain.make(router_group_guid: router_group.guid, name: 'my.domain') }
        let!(:route_with_ports_0) do
          VCAP::CloudController::Route.make(host: '', space: space, domain: domain_tcp, guid: 'route-with-port-0', port: 7777)
        end
        let!(:route_with_ports_1) do
          VCAP::CloudController::Route.make(host: '', space: space, domain: domain_tcp, guid: 'route-with-port-1', port: 8888)
        end
        let!(:route_with_ports_2) do
          VCAP::CloudController::Route.make(host: '', space: space, domain: domain_tcp, guid: 'route-with-port-2', port: 9999)
        end
        let!(:route_mapping_1) { VCAP::CloudController::RouteMappingModel.make(app: app_model, route: route_with_ports_1, process_type: 'web') }
        let!(:route_mapping_2) { VCAP::CloudController::RouteMappingModel.make(app: app_model, route: route_with_ports_2, process_type: 'web') }

        it 'returns routes filtered by ports' do
          get "/v3/apps/#{app_model.guid}/routes?ports=7777,8888", nil, admin_header
          expect(last_response).to have_status_code(200)
          expect(parsed_response['resources'].size).to eq(1)
          expect(parsed_response['resources'].first['port']).to eq(route_with_ports_1.port)
        end
      end
    end

    describe 'eager loading' do
      it 'eager loads associated resources that the presenter specifies' do
        expect(VCAP::CloudController::RouteFetcher).to receive(:fetch).with(
          anything,
          hash_including(eager_loaded_associations: %i[domain space route_mappings labels annotations])
        ).and_call_original

        get "/v3/apps/#{app_model.guid}/routes", nil, admin_header
        expect(last_response).to have_status_code(200)
      end
    end
  end
end
