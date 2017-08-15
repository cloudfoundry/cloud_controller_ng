require 'spec_helper'

module VCAP::CloudController
  module Diego
    class Protocol
      RSpec.describe RoutingInfo do
        describe 'routing_info' do
          subject(:routing_info) { RoutingInfo.new(process) }
          let(:ri) { routing_info.routing_info }

          let(:org) { Organization.make }
          let(:space_quota) { SpaceQuotaDefinition.make(organization: org) }
          let(:space) { Space.make(organization: org, space_quota_definition: space_quota) }
          let(:domain) { PrivateDomain.make(name: 'mydomain.com', owning_organization: org) }
          let(:process) { ProcessModelFactory.make(space: space, diego: true) }
          let(:route_without_service) { Route.make(host: 'host2', domain: domain, space: space, path: '/my%20path') }
          let(:route_with_service) do
            route            = Route.make(host: 'myhost', domain: domain, space: space, path: '/my%20path')
            service_instance = ManagedServiceInstance.make(:routing, space: space)
            RouteBinding.make(route: route, service_instance: service_instance)
            route
          end

          let(:router_group_guid) { 'router-group-guid-1' }
          let(:router_group_type) { 'tcp' }
          let(:routing_api_client) { instance_double(VCAP::CloudController::RoutingApi::Client, router_group: router_group) }
          let(:router_group) { VCAP::CloudController::RoutingApi::RouterGroup.new({
              'guid' => router_group_guid,
              'type' => router_group_type,
              'name' => 'router-group-1' }
          )
          }

          before do
            allow_any_instance_of(RouteValidator).to receive(:validate)
            allow_any_instance_of(SharedDomain).to receive(:routing_api_client).and_return(routing_api_client)
            allow(routing_api_client).to receive(:router_groups).and_return([router_group])
          end

          context 'http routes' do
            context 'with no app ports specified in route mapping' do
              before do
                RouteMappingModel.make(app: process.app, route: route_with_service, process_type: process.type, app_port: ProcessModel::NO_APP_PORT_SPECIFIED)
                RouteMappingModel.make(app: process.app, route: route_without_service, process_type: process.type, app_port: ProcessModel::NO_APP_PORT_SPECIFIED)
              end

              context 'and app has no ports' do
                it 'returns the mapped http routes associated with the app with a default of port 8080' do
                  expected_http = [
                    { 'hostname' => route_with_service.uri, 'route_service_url' => route_with_service.route_service_url, 'port' => 8080 },
                    { 'hostname' => route_without_service.uri, 'port' => 8080 }
                  ]

                  expect(ri.keys).to match_array ['http_routes']
                  expect(ri['http_routes']).to match_array expected_http
                end
              end

              context 'and app has ports' do
                let(:process) { ProcessModelFactory.make(space: space, diego: true, ports: [7890, 8080]) }

                it 'uses the first port available on the app' do
                  expected_http = [
                    { 'hostname' => route_with_service.uri, 'route_service_url' => route_with_service.route_service_url, 'port' => 7890 },
                    { 'hostname' => route_without_service.uri, 'port' => 7890 }
                  ]

                  expect(ri.keys).to match_array ['http_routes']
                  expect(ri['http_routes']).to match_array expected_http
                end
              end

              describe 'docker ports' do
                let(:parent_app) { AppModel.make(:docker, space: space) }
                let(:process) { ProcessModelFactory.make(app: parent_app, diego: true) }
                let(:droplet) do
                  DropletModel.make(
                    :docker,
                      state: DropletModel::STAGED_STATE,
                      app: parent_app,
                      execution_metadata: execution_metadata,
                      docker_receipt_image: 'foo/bar'
                  )
                end

                before do
                  parent_app.update(droplet_guid: droplet.guid)
                  process.reload
                end

                context 'when the app has no docker ports' do
                  let(:execution_metadata) { '{}' }

                  it 'uses 8080 as a default' do
                    expected_http = [
                      { 'hostname' => route_with_service.uri, 'route_service_url' => route_with_service.route_service_url, 'port' => 8080 },
                      { 'hostname' => route_without_service.uri, 'port' => 8080 }
                    ]

                    expect(ri.keys).to match_array ['http_routes']
                    expect(ri['http_routes']).to match_array expected_http
                  end
                end

                context 'and app has docker ports' do
                  let(:execution_metadata) { '{"ports":[{"Port":1024, "Protocol":"tcp"}, {"Port":4444, "Protocol":"udp"},{"Port":1025, "Protocol":"tcp"}]}' }

                  it 'uses the first docker port available on the app' do
                    expected_http = [
                      { 'hostname' => route_with_service.uri, 'route_service_url' => route_with_service.route_service_url, 'port' => 1024 },
                      { 'hostname' => route_without_service.uri, 'port' => 1024 }
                    ]

                    expect(ri.keys).to match_array ['http_routes']
                    expect(ri['http_routes']).to match_array expected_http
                  end
                end
              end
            end

            context 'with app port specified in route mapping' do
              let(:process) { ProcessModelFactory.make(space: space, diego: true, ports: [9090]) }
              let!(:route_mapping) { RouteMappingModel.make(app: process.app, route: route_with_service, app_port: 9090) }

              it 'returns the app port in routing info' do
                expected_http = [
                  { 'hostname' => route_with_service.uri, 'route_service_url' => route_with_service.route_service_url, 'port' => 9090 },
                ]

                expect(ri.keys).to match_array ['http_routes']
                expect(ri['http_routes']).to match_array expected_http
              end
            end

            context 'with multiple route mapping to same route with different app ports' do
              let(:process) { ProcessModelFactory.make(space: space, diego: true, ports: [8080, 9090]) }
              let!(:route_mapping1) { RouteMappingModel.make(app: process.app, route: route_with_service, app_port: 8080) }
              let!(:route_mapping2) { RouteMappingModel.make(app: process.app, route: route_with_service, app_port: 9090) }

              it 'returns the app port in routing info' do
                expected_http = [
                  { 'hostname' => route_with_service.uri, 'route_service_url' => route_with_service.route_service_url, 'port' => 8080 },
                  { 'hostname' => route_with_service.uri, 'route_service_url' => route_with_service.route_service_url, 'port' => 9090 },
                ]

                expect(ri.keys).to match_array ['http_routes']
                expect(ri['http_routes']).to match_array expected_http
              end
            end

            context 'with multiple route mapping to different route with same app port' do
              let(:process) { ProcessModelFactory.make(space: space, diego: true, ports: [9090]) }
              let!(:route_mapping1) { RouteMappingModel.make(app: process.app, route: route_without_service, app_port: 9090) }
              let!(:route_mapping2) { RouteMappingModel.make(app: process.app, route: route_with_service, app_port: 9090) }

              it 'returns the app port in routing info' do
                expected_http = [
                  { 'hostname' => route_without_service.uri, 'port' => 9090 },
                  { 'hostname' => route_with_service.uri, 'route_service_url' => route_with_service.route_service_url, 'port' => 9090 },
                ]

                expect(ri.keys).to match_array ['http_routes']
                expect(ri['http_routes']).to match_array expected_http
              end
            end

            context 'with multiple route mapping to different route with different app ports' do
              let(:process) { ProcessModelFactory.make(space: space, diego: true, ports: [8080, 9090]) }
              let!(:route_mapping1) { RouteMappingModel.make(app: process.app, route: route_without_service, app_port: 8080) }
              let!(:route_mapping2) { RouteMappingModel.make(app: process.app, route: route_with_service, app_port: 9090) }

              it 'returns the app port in routing info' do
                expected_http = [
                  { 'hostname' => route_without_service.uri, 'port' => 8080 },
                  { 'hostname' => route_with_service.uri, 'route_service_url' => route_with_service.route_service_url, 'port' => 9090 },
                ]
                expect(ri.keys).to match_array ['http_routes']
                expect(ri['http_routes']).to match_array expected_http
              end
            end

            context 'when using a router group' do
              let(:router_group_type) { 'http' }
              let(:domain) { SharedDomain.make(name: 'httpdomain.com', router_group_guid: router_group_guid) }
              let(:http_route) { Route.make(domain: domain, space: space, port: 8080) }
              let!(:route_mapping) { RouteMappingModel.make(app: process.app, route: http_route) }

              it 'returns the router group guid in the http routing info' do
                expect(ri.keys).to contain_exactly('http_routes')
                hr = ri['http_routes'][0]
                expect(hr.keys).to contain_exactly('router_group_guid', 'port', 'hostname')
                expect(hr['router_group_guid']).to eql(domain.router_group_guid)
                expect(hr['port']).to eql(http_route.port)
                expect(hr['hostname']).to match(/host-[0-9]+\.#{domain.name}/)
              end
            end
          end

          context 'tcp routes' do
            let!(:domain) { SharedDomain.make(name: 'tcpdomain.com', router_group_guid: 'router-group-guid-1') }
            let(:process) { ProcessModelFactory.make(space: space, diego: true, ports: [9090]) }
            let(:tcp_route) { Route.make(domain: domain, space: space, port: 52000) }

            context 'with only one app port mapped to route' do
              let!(:route_mapping) { RouteMappingModel.make(app: process.app, route: tcp_route, app_port: 9090) }

              it 'returns the app port in routing info' do
                expected_tcp = [
                  { 'router_group_guid' => domain.router_group_guid, 'external_port' => tcp_route.port, 'container_port' => 9090 },
                ]

                expect(ri.keys).to match_array ['tcp_routes']
                expect(ri['tcp_routes']).to match_array expected_tcp
              end
            end

            context 'with multiple app ports Îmapped to same route' do
              let(:process) { ProcessModelFactory.make(space: space, diego: true, ports: [9090, 5555]) }
              let!(:route_mapping_1) { RouteMappingModel.make(app: process.app, route: tcp_route, app_port: 9090) }
              let!(:route_mapping_2) { RouteMappingModel.make(app: process.app, route: tcp_route, app_port: 5555) }

              it 'returns the app ports in routing info' do
                expected_tcp = [
                  { 'router_group_guid' => domain.router_group_guid, 'external_port' => tcp_route.port, 'container_port' => 9090 },
                  { 'router_group_guid' => domain.router_group_guid, 'external_port' => tcp_route.port, 'container_port' => 5555 },
                ]

                expect(ri.keys).to match_array ['tcp_routes']
                expect(ri['tcp_routes']).to match_array expected_tcp
              end
            end

            context 'with same app port mapped to different routes' do
              let(:tcp_route_1) { Route.make(domain: domain, space: space, port: 52000) }
              let(:tcp_route_2) { Route.make(domain: domain, space: space, port: 52001) }
              let!(:route_mapping_1) { RouteMappingModel.make(app: process.app, route: tcp_route_1, app_port: 9090) }
              let!(:route_mapping_2) { RouteMappingModel.make(app: process.app, route: tcp_route_2, app_port: 9090) }

              it 'returns the app ports in routing info' do
                expected_routes = [
                  { 'router_group_guid' => domain.router_group_guid, 'external_port' => tcp_route_1.port, 'container_port' => 9090 },
                  { 'router_group_guid' => domain.router_group_guid, 'external_port' => tcp_route_2.port, 'container_port' => 9090 },
                ]

                expect(ri.keys).to match_array ['tcp_routes']
                expect(ri['tcp_routes']).to match_array expected_routes
              end
            end

            context 'with different app ports mapped to different routes' do
              let(:process) { ProcessModelFactory.make(space: space, diego: true, ports: [9090, 5555]) }
              let(:tcp_route_1) { Route.make(domain: domain, space: space, port: 52000) }
              let(:tcp_route_2) { Route.make(domain: domain, space: space, port: 52001) }
              let!(:route_mapping_1) { RouteMappingModel.make(app: process.app, route: tcp_route_1, app_port: 9090) }
              let!(:route_mapping_2) { RouteMappingModel.make(app: process.app, route: tcp_route_2, app_port: 5555) }

              it 'returns the multiple route mappings in routing info' do
                expected_routes = [
                  { 'router_group_guid' => domain.router_group_guid, 'external_port' => tcp_route_1.port, 'container_port' => 9090 },
                  { 'router_group_guid' => domain.router_group_guid, 'external_port' => tcp_route_2.port, 'container_port' => 5555 },
                ]

                expect(ri.keys).to match_array ['tcp_routes']
                expect(ri['tcp_routes']).to match_array expected_routes
              end
            end
          end

          context 'with both http and tcp routes' do
            let(:process) { ProcessModelFactory.make(space: space, diego: true, ports: [8080, 9090, 5555]) }

            let(:http_domain) { SharedDomain.make(name: 'httpdomain.com', router_group_guid: router_group_guid_1) }
            let(:http_route) { Route.make(domain: domain, space: space, port: 8080) }

            let(:tcp_domain) { SharedDomain.make(name: 'tcpdomain.com', router_group_guid: router_group_guid_2) }
            let(:tcp_route) { Route.make(domain: tcp_domain, space: space, port: 52000) }

            let!(:route_mapping_1) { RouteMappingModel.make(app: process.app, route: http_route, app_port: 8080) }
            let!(:route_mapping_2) { RouteMappingModel.make(app: process.app, route: http_route, app_port: 9090) }
            let!(:tcp_route_mapping) { RouteMappingModel.make(app: process.app, route: tcp_route, app_port: 5555) }

            let(:router_group_guid_1) { 'router-group-guid-1' }
            let(:router_group_guid_2) { 'router-group-guid-2' }
            let(:router_group_type_http) { 'http' }
            let(:router_group_type_tcp) { 'tcp' }
            let(:router_group_1) { VCAP::CloudController::RoutingApi::RouterGroup.new({
                                                                                        'guid' => router_group_guid_1,
                                                                                        'type' => router_group_type_http,
                                                                                        'name' => 'router-group-1' }
            )
            }
            let(:router_group_2) { VCAP::CloudController::RoutingApi::RouterGroup.new({
                                                                                        'guid' => router_group_guid_2,
                                                                                        'type' => router_group_type_tcp,
                                                                                        'name' => 'router-group-1' }
            )
            }

            before do
              allow(routing_api_client).to receive(:router_groups).and_return([router_group_1, router_group_2])
            end

            it 'returns the app port in routing info' do
              expected_tcp = [
                { 'router_group_guid' => tcp_domain.router_group_guid, 'external_port' => tcp_route.port, 'container_port' => 5555 },
              ]

              expect(ri.keys).to match_array ['tcp_routes', 'http_routes']
              expect(ri['tcp_routes']).to match_array expected_tcp
              http_ports = ri['http_routes'].map { |hr| hr['port'] }
              expect(http_ports).to contain_exactly(8080, 9090)
            end

            context 'errors in the routing_api_client' do
              it 'turns RoutingApiDisabled into an ApiError' do
                allow(routing_api_client).to receive(:router_group).and_raise(RoutingApi::RoutingApiDisabled)
                expect { ri }.to raise_error(CloudController::Errors::ApiError)
              end

              it 'turns RoutingApiUnavailable into an ApiError' do
                allow(routing_api_client).to receive(:router_group).and_raise(RoutingApi::RoutingApiUnavailable)
                expect { ri }.to raise_error(CloudController::Errors::ApiError)
              end

              it 'turns UaaUnavailable into an ApiError' do
                allow(routing_api_client).to receive(:router_group).and_raise(RoutingApi::UaaUnavailable)
                expect { ri }.to raise_error(CloudController::Errors::ApiError)
              end
            end
          end
        end
      end
    end
  end
end
