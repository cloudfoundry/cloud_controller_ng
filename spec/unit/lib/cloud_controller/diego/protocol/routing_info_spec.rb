require 'spec_helper'

module VCAP::CloudController
  module Diego
    class Protocol
      RSpec.describe RoutingInfo do
        describe 'routing_info' do
          subject(:routing_info) { RoutingInfo.new(app).routing_info }

          let(:org) { Organization.make }
          let(:space_quota) { SpaceQuotaDefinition.make(organization: org) }
          let(:space) { Space.make(organization: org, space_quota_definition: space_quota) }
          let(:domain) { PrivateDomain.make(name: 'mydomain.com', owning_organization: org) }
          let(:app) { AppFactory.make(space: space, diego: true) }
          let(:route_without_service) { Route.make(host: 'host2', domain: domain, space: space, path: '/my%20path') }
          let(:route_with_service) do
            route            = Route.make(host: 'myhost', domain: domain, space: space, path: '/my%20path')
            service_instance = ManagedServiceInstance.make(:routing, space: space)
            RouteBinding.make(route: route, service_instance: service_instance)
            route
          end
          before do
            allow_any_instance_of(RouteValidator).to receive(:validate)
          end

          context 'with no app ports specified in route mapping' do
            before do
              app.add_route(route_with_service)
              app.add_route(route_without_service)
            end

            context 'and app has no ports' do
              it 'returns the mapped http routes associated with the app with a default of port 8080' do
                expected_http = [
                  { 'hostname' => route_with_service.uri, 'route_service_url' => route_with_service.route_service_url, 'port' => 8080 },
                  { 'hostname' => route_without_service.uri, 'port' => 8080 }
                ]

                expect(routing_info.keys).to match_array ['http_routes']
                expect(routing_info['http_routes']).to match_array expected_http
              end
            end

            context 'and app has ports' do
              let(:app) { AppFactory.make(space: space, diego: true, ports: [7890, 8080]) }

              it 'uses the first port available on the app' do
                expected_http = [
                  { 'hostname' => route_with_service.uri, 'route_service_url' => route_with_service.route_service_url, 'port' => 7890 },
                  { 'hostname' => route_without_service.uri, 'port' => 7890 }
                ]

                expect(routing_info.keys).to match_array ['http_routes']
                expect(routing_info['http_routes']).to match_array expected_http
              end
            end

            shared_examples_for 'it routes docker ports' do
              context 'when the app has no docker ports' do
                let(:execution_metadata) { '{}' }

                it 'uses 8080 as a default' do
                  expected_http = [
                    { 'hostname' => route_with_service.uri, 'route_service_url' => route_with_service.route_service_url, 'port' => 8080 },
                    { 'hostname' => route_without_service.uri, 'port' => 8080 }
                  ]

                  expect(routing_info.keys).to match_array ['http_routes']
                  expect(routing_info['http_routes']).to match_array expected_http
                end
              end

              context 'and app has docker ports' do
                let(:execution_metadata) { '{"ports":[{"Port":1024, "Protocol":"tcp"}, {"Port":4444, "Protocol":"udp"},{"Port":1025, "Protocol":"tcp"}]}' }

                it 'uses the first docker port available on the app' do
                  expected_http = [
                    { 'hostname' => route_with_service.uri, 'route_service_url' => route_with_service.route_service_url, 'port' => 1024 },
                    { 'hostname' => route_without_service.uri, 'port' => 1024 }
                  ]

                  expect(routing_info.keys).to match_array ['http_routes']
                  expect(routing_info['http_routes']).to match_array expected_http
                end
              end
            end

            context 'v2' do
              let(:app) { AppFactory.make(space: space, diego: true, docker_image: 'foo/bar') }
              let!(:droplet) { Droplet.make(app: app, execution_metadata: execution_metadata) }

              before do
                app.droplet_hash = droplet.droplet_hash
                app.save
              end

              it_behaves_like 'it routes docker ports'
            end

            context 'v3' do
              let(:app) { AppFactory.make(space: space, diego: true, docker_image: 'foo/bar') }
              let!(:droplet) { DropletModel.make(:docker, execution_metadata: execution_metadata) }

              before do
                app.app = droplet.app
              end

              it_behaves_like 'it routes docker ports'
            end
          end

          context 'with app port specified in route mapping' do
            let(:app) { AppFactory.make(space: space, diego: true, ports: [9090]) }
            let!(:route_mapping) { RouteMapping.make(app: app, route: route_with_service, app_port: 9090) }

            it 'returns the app port in routing info' do
              expected_http = [
                { 'hostname' => route_with_service.uri, 'route_service_url' => route_with_service.route_service_url, 'port' => 9090 },
              ]

              expect(routing_info.keys).to match_array ['http_routes']
              expect(routing_info['http_routes']).to match_array expected_http
            end
          end

          context 'with multiple route mapping to same route with different app ports' do
            let(:app) { AppFactory.make(space: space, diego: true, ports: [8080, 9090]) }
            let!(:route_mapping1) { RouteMapping.make(app: app, route: route_with_service, app_port: 8080) }
            let!(:route_mapping2) { RouteMapping.make(app: app, route: route_with_service, app_port: 9090) }

            it 'returns the app port in routing info' do
              expected_http = [
                { 'hostname' => route_with_service.uri, 'route_service_url' => route_with_service.route_service_url, 'port' => 8080 },
                { 'hostname' => route_with_service.uri, 'route_service_url' => route_with_service.route_service_url, 'port' => 9090 },
              ]

              expect(routing_info.keys).to match_array ['http_routes']
              expect(routing_info['http_routes']).to match_array expected_http
            end
          end

          context 'with multiple route mapping to different route with same app port' do
            let(:app) { AppFactory.make(space: space, diego: true, ports: [9090]) }
            let!(:route_mapping1) { RouteMapping.make(app: app, route: route_without_service, app_port: 9090) }
            let!(:route_mapping2) { RouteMapping.make(app: app, route: route_with_service, app_port: 9090) }

            it 'returns the app port in routing info' do
              expected_http = [
                { 'hostname' => route_without_service.uri, 'port' => 9090 },
                { 'hostname' => route_with_service.uri, 'route_service_url' => route_with_service.route_service_url, 'port' => 9090 },
              ]

              expect(routing_info.keys).to match_array ['http_routes']
              expect(routing_info['http_routes']).to match_array expected_http
            end
          end

          context 'with multiple route mapping to different route with different app ports' do
            let(:app) { AppFactory.make(space: space, diego: true, ports: [8080, 9090]) }
            let!(:route_mapping1) { RouteMapping.make(app: app, route: route_without_service, app_port: 8080) }
            let!(:route_mapping2) { RouteMapping.make(app: app, route: route_with_service, app_port: 9090) }

            it 'returns the app port in routing info' do
              expected_http = [
                { 'hostname' => route_without_service.uri, 'port' => 8080 },
                { 'hostname' => route_with_service.uri, 'route_service_url' => route_with_service.route_service_url, 'port' => 9090 },
              ]
              expect(routing_info.keys).to match_array ['http_routes']
              expect(routing_info['http_routes']).to match_array expected_http
            end
          end

          context 'tcp routes' do
            context 'with only one app port mapped to route' do
              let(:app) { AppFactory.make(space: space, diego: true, ports: [9090]) }
              let(:domain) { SharedDomain.make(name: 'tcpdomain.com', router_group_guid: 'router-group-guid-1') }
              let(:tcp_route) { Route.make(domain: domain, space: space, port: 52000) }
              let!(:route_mapping) { RouteMapping.make(app: app, route: tcp_route, app_port: 9090) }

              it 'returns the app port in routing info' do
                expected_tcp = [
                  { 'router_group_guid' => domain.router_group_guid, 'external_port' => tcp_route.port, 'container_port' => 9090 },
                ]

                expect(routing_info.keys).to match_array ['tcp_routes']
                expect(routing_info['tcp_routes']).to match_array expected_tcp
              end
            end

            context 'with multiple app ports mapped to same route' do
              let(:app) { AppFactory.make(space: space, diego: true, ports: [9090, 5555]) }
              let(:domain) { SharedDomain.make(name: 'tcpdomain.com', router_group_guid: 'router-group-guid-1') }
              let(:tcp_route) { Route.make(domain: domain, space: space, port: 52000) }
              let!(:route_mapping_1) { RouteMapping.make(app: app, route: tcp_route, app_port: 9090) }
              let!(:route_mapping_2) { RouteMapping.make(app: app, route: tcp_route, app_port: 5555) }

              it 'returns the app ports in routing info' do
                expected_tcp = [
                  { 'router_group_guid' => domain.router_group_guid, 'external_port' => tcp_route.port, 'container_port' => 9090 },
                  { 'router_group_guid' => domain.router_group_guid, 'external_port' => tcp_route.port, 'container_port' => 5555 },
                ]

                expect(routing_info.keys).to match_array ['tcp_routes']
                expect(routing_info['tcp_routes']).to match_array expected_tcp
              end
            end

            context 'with same app port mapped to different routes' do
              let(:app) { AppFactory.make(space: space, diego: true, ports: [9090]) }
              let(:domain) { SharedDomain.make(name: 'tcpdomain.com', router_group_guid: 'router-group-guid-1') }
              let(:tcp_route_1) { Route.make(domain: domain, space: space, port: 52000) }
              let(:tcp_route_2) { Route.make(domain: domain, space: space, port: 52001) }
              let!(:route_mapping_1) { RouteMapping.make(app: app, route: tcp_route_1, app_port: 9090) }
              let!(:route_mapping_2) { RouteMapping.make(app: app, route: tcp_route_2, app_port: 9090) }

              it 'returns the app ports in routing info' do
                expected_routes = [
                  { 'router_group_guid' => domain.router_group_guid, 'external_port' => tcp_route_1.port, 'container_port' => 9090 },
                  { 'router_group_guid' => domain.router_group_guid, 'external_port' => tcp_route_2.port, 'container_port' => 9090 },
                ]

                expect(routing_info.keys).to match_array ['tcp_routes']
                expect(routing_info['tcp_routes']).to match_array expected_routes
              end
            end

            context 'with different app ports mapped to different routes' do
              let(:app) { AppFactory.make(space: space, diego: true, ports: [9090, 5555]) }
              let(:domain) { SharedDomain.make(name: 'tcpdomain.com', router_group_guid: 'router-group-guid-1') }
              let(:tcp_route_1) { Route.make(domain: domain, space: space, port: 52000) }
              let(:tcp_route_2) { Route.make(domain: domain, space: space, port: 52001) }
              let!(:route_mapping_1) { RouteMapping.make(app: app, route: tcp_route_1, app_port: 9090) }
              let!(:route_mapping_2) { RouteMapping.make(app: app, route: tcp_route_2, app_port: 5555) }

              it 'returns the multiple route mappings in routing info' do
                expected_routes = [
                  { 'router_group_guid' => domain.router_group_guid, 'external_port' => tcp_route_1.port, 'container_port' => 9090 },
                  { 'router_group_guid' => domain.router_group_guid, 'external_port' => tcp_route_2.port, 'container_port' => 5555 },
                ]

                expect(routing_info.keys).to match_array ['tcp_routes']
                expect(routing_info['tcp_routes']).to match_array expected_routes
              end
            end
          end

          context 'with both http and tcp routes' do
            let(:app) { AppFactory.make(space: space, diego: true, ports: [8080, 9090, 5555]) }
            let(:tcp_domain) { SharedDomain.make(name: 'tcpdomain.com', router_group_guid: 'router-group-guid-1') }
            let(:tcp_route) { Route.make(domain: tcp_domain, space: space, port: 52000) }
            let!(:route_mapping_1) { RouteMapping.make(app: app, route: route_with_service, app_port: 8080) }
            let!(:route_mapping_2) { RouteMapping.make(app: app, route: route_with_service, app_port: 9090) }
            let!(:tcp_route_mapping) { RouteMapping.make(app: app, route: tcp_route, app_port: 5555) }

            it 'returns the app port in routing info' do
              expected_http = [
                { 'hostname' => route_with_service.uri, 'route_service_url' => route_with_service.route_service_url, 'port' => 8080 },
                { 'hostname' => route_with_service.uri, 'route_service_url' => route_with_service.route_service_url, 'port' => 9090 },
              ]

              expected_tcp = [
                { 'router_group_guid' => tcp_domain.router_group_guid, 'external_port' => tcp_route.port, 'container_port' => 5555 },
              ]

              expect(routing_info.keys).to match_array ['tcp_routes', 'http_routes']
              expect(routing_info['tcp_routes']).to match_array expected_tcp
              expect(routing_info['http_routes']).to match_array expected_http
            end
          end
        end
      end
    end
  end
end
