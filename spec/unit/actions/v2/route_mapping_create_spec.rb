require 'spec_helper'

module VCAP::CloudController
  module V2
    RSpec.describe RouteMappingCreate do
      subject(:route_mapping_create) { RouteMappingCreate.new(user_audit_info, route, process, request_attrs) }

      let(:space) { app.space }
      let(:app) { AppModel.make }
      let(:user_guid) { 'user-guid' }
      let(:user_email) { '1@2.3' }
      let(:user_audit_info) { UserAuditInfo.new(user_email: user_email, user_guid: user_guid) }
      let(:process) { ProcessModel.make(:process, app: app, type: process_type, ports: ports, health_check_type: 'none') }
      let(:process_type) { 'web' }
      let(:ports) { [8888] }
      let(:requested_port) { 8888 }
      let(:route_handler) { instance_double(ProcessRouteHandler, update_route_information: nil) }
      let(:request_attrs) { { 'app_port' => requested_port } }

      before do
        allow(ProcessRouteHandler).to receive(:new).and_return(route_handler)
      end

      describe '#add' do
        let(:route) { Route.make(space: space) }

        it 'maps the route' do
          expect {
            route_mapping = route_mapping_create.add
            expect(route_mapping.route.guid).to eq(route.guid)
            expect(route_mapping.process.guid).to eq(process.guid)
          }.to change { RouteMappingModel.count }.by(1)
        end

        it 'delegates to the route handler to update route information' do
          route_mapping_create.add
          expect(route_handler).to have_received(:update_route_information)
        end

        describe 'app_port' do
          context 'when the user requested an app port' do
            let(:requested_port) { 8888 }

            it 'requests that port' do
              route_mapping = route_mapping_create.add
              expect(route_mapping.app_port).to eq(8888)
            end
          end

          context 'when the user did not request an app port' do
            let(:request_attrs) { {} }

            context 'when the process has ports' do
              let(:process) { ProcessModelFactory.make(space: route.space, diego: true, ports: [1234, 5678]) }

              it 'requests the first port from the process port list' do
                route_mapping = route_mapping_create.add
                expect(route_mapping.app_port).to eq(1234)
              end
            end

            context 'when the process has no ports' do
              let(:process) { ProcessModelFactory.make(space: route.space, diego: true, ports: nil) }

              it 'uses the default port' do
                route_mapping = route_mapping_create.add
                expect(route_mapping.app_port).to eq(ProcessModel::DEFAULT_HTTP_PORT)
              end
            end
          end

          context 'docker' do
            let(:process) { ProcessModelFactory.make(diego: true, ports: [1234, 5678], health_check_type: 'none', docker_image: 'docker/image') }
            let(:app) { process.app }

            context 'when app_port is requested' do
              let(:requested_port) { 8888 }

              before do
                allow_any_instance_of(AppModel).to receive(:lifecycle_type).and_return(DockerLifecycleDataModel::LIFECYCLE_TYPE)
              end

              it 'does not validate' do
                mapping = route_mapping_create.add
                expect(app.reload.routes).to eq([route])
                expect(mapping.app_port).to eq(8888)
              end
            end

            context 'when app_port is not specified' do
              let(:requested_port) { nil }

              it 'defaults to "ProcessModel::NO_APP_PORT_SPECIFIED"' do
                mapping = route_mapping_create.add
                expect(app.reload.routes).to eq([route])
                expect(mapping.app_port).to eq(ProcessModel::NO_APP_PORT_SPECIFIED)
              end
            end
          end
        end

        context 'when the process type does not yet exist' do
          let(:process_type) { 'worker' }

          it 'still creates the route mapping' do
            route_mapping_create.add
            expect(app.reload.routes).to eq([route])
            expect(RouteMappingModel.first.process_type).to eq 'worker'
          end
        end

        context 'when the process is web' do
          let(:process_type) { 'web' }

          context 'dea' do
            let(:process) { ProcessModel.make(diego: false, app: app, type: process_type, health_check_type: 'none') }

            context 'not requesting a port' do
              let(:request_attrs) { {} }

              it 'succeeds' do
                route_mapping_create.add
                expect(app.reload.routes).to eq([route])
              end
            end

            context 'when requesting a port' do
              let(:requested_port) { 4443 }

              it 'raises AppPortNotSupportedError' do
                expect { route_mapping_create.add }.to raise_error(RouteMappingCreate::AppPortNotSupportedError)
              end
            end
          end

          context 'diego' do
            let(:process) { ProcessModel.make(diego: true, app: app, type: process_type, ports: [1234, 5678], health_check_type: 'none') }

            context 'requesting available port' do
              let(:requested_port) { 5678 }
              it 'succeeds' do
                mapping = route_mapping_create.add
                expect(app.reload.routes).to eq([route])
                expect(mapping.app_port).to eq(5678)
              end
            end

            context 'requesting unavailable' do
              let(:requested_port) { 8888 }
              it 'raises' do
                expect {
                  route_mapping_create.add
                }.to raise_error(RouteMappingCreate::UnavailableAppPort, /8888 is not available/)
              end
            end

            context 'not requesting a port' do
              let(:request_attrs) { {} }

              it 'succeeds using the first available port from the process' do
                mapping = route_mapping_create.add
                expect(app.reload.routes).to eq([route])
                expect(mapping.app_port).to eq(1234)
              end
            end
          end
        end

        context 'when the process is not web' do
          let(:process_type) { 'baboon' }

          context 'when no app port is requested' do
            let(:requested_port) { nil }

            it 'raises' do
              expect {
                route_mapping_create.add
              }.to raise_error(RouteMappingCreate::InvalidRouteMapping, /must be specified/)
            end
          end

          context 'when the default web port is requested' do
            let(:requested_port) { 8080 }

            context 'when the process has an empty array of ports' do
              let(:ports) { [] }
              it 'raises' do
                expect {
                  route_mapping_create.add
                }.to raise_error(RouteMappingCreate::UnavailableAppPort, /8080 is not available/)
              end
            end

            context 'when the process has nil ports' do
              let(:ports) { nil }
              it 'raises' do
                expect {
                  route_mapping_create.add
                }.to raise_error(RouteMappingCreate::UnavailableAppPort, /8080 is not available/)
              end
            end
          end

          context 'a non-default port is requested' do
            let(:requested_port) { 1234 }

            context 'when the process has an empty array of ports' do
              let(:ports) { [] }
              it 'raises' do
                expect {
                  route_mapping_create.add
                }.to raise_error(RouteMappingCreate::UnavailableAppPort, /1234 is not available/)
              end
            end

            context 'when the process has nil ports' do
              let(:ports) { nil }
              it 'raises' do
                expect {
                  route_mapping_create.add
                }.to raise_error(RouteMappingCreate::UnavailableAppPort, /1234 is not available/)
              end
            end
          end
        end

        context 'when a route mapping already exists and a new mapping is requested' do
          before do
            route_mapping_create.add
          end

          context 'for the same process type' do
            it 'does not allow for duplicate route association' do
              expect {
                route_mapping_create.add
              }.to raise_error(RouteMappingCreate::DuplicateRouteMapping, /Duplicate Route Mapping/)
              expect(app.reload.routes).to eq([route])
            end
          end

          context 'for a different process type' do
            let(:worker_process) { ProcessModel.make(:process, app: app, type: 'worker', ports: [8888]) }

            it 'allows a new route mapping' do
              RouteMappingCreate.new(user_audit_info, route, worker_process, request_attrs).add
              expect(app.reload.routes).to eq([route, route])
            end
          end
        end

        context 'when the mapping is invalid' do
          before do
            allow(RouteMappingModel).to receive(:new).and_raise(Sequel::ValidationFailed.new('shizzle'))
          end

          it 'raises an InvalidRouteMapping error' do
            expect {
              route_mapping_create.add
            }.to raise_error(RouteMappingCreate::InvalidRouteMapping, 'shizzle')
          end
        end

        context 'when the app and route are in different spaces' do
          let(:route) { Route.make(space: Space.make) }

          it 'raises InvalidRouteMapping' do
            expect {
              route_mapping_create.add
            }.to raise_error(RouteMappingCreate::InvalidRouteMapping, /the app and route must belong to the same space/)
            expect(app.reload.routes).to be_empty
          end
        end

        context 'when the route is bound to a route service' do
          let(:route_binding) { RouteBinding.make }
          let(:route) { route_binding.route }

          context 'running on diego' do
            let(:process) { ProcessModelFactory.make(space: route.space, diego: true, ports: ports) }

            it 'maps the route' do
              expect {
                route_mapping = route_mapping_create.add
                expect(route_mapping.route.guid).to eq(route.guid)
                expect(route_mapping.process.guid).to eq(process.guid)
                expect(route_mapping.app_port).to eq(8888)
              }.to change { RouteMappingModel.count }.by(1)
            end
          end

          context 'running on dea backend' do
            let(:process) { ProcessModelFactory.make(space: route.space, diego: false) }

            it 'raises RouteServiceNotSupportedError' do
              expect { route_mapping_create.add }.to raise_error(RouteMappingCreate::RouteServiceNotSupportedError)
            end
          end
        end

        context 'when the route has a tcp domain' do
          let(:router_group_guid) { 'router-group-guid-1' }
          let(:routing_api_client) { double('routing_api_client', router_group: router_group) }
          let(:router_group) { double('router_group', type: 'tcp', guid: router_group_guid) }
          let(:dependency_double) { double('dependency_locator', routing_api_client: routing_api_client) }
          let(:tcp_domain) { SharedDomain.make(name: 'tcpdomain.com', router_group_guid: router_group_guid) }
          let(:route) { Route.make(domain: tcp_domain, port: 5155, space: space) }

          before do
            allow(CloudController::DependencyLocator).to receive(:instance).and_return(dependency_double)
            allow_any_instance_of(RouteValidator).to receive(:validate)
          end

          it 'maps the route' do
            expect {
              route_mapping = route_mapping_create.add
              expect(route_mapping.route.guid).to eq(route.guid)
              expect(route_mapping.process.guid).to eq(process.guid)
            }.to change { RouteMappingModel.count }.by(1)
          end

          context 'when the routing api is disabled' do
            before do
              TestConfig.config[:routing_api] = nil
            end

            it 'raises RoutingApiDisabledError' do
              expect { route_mapping_create.add }.to raise_error(RouteMappingCreate::RoutingApiDisabledError)
            end
          end
        end

        describe 'recording events' do
          let(:event_repository) { double(Repositories::AppEventRepository) }

          before do
            allow(Repositories::AppEventRepository).to receive(:new).and_return(event_repository)
            allow(event_repository).to receive(:record_map_route)
          end

          it 'creates an event for adding a route to an app' do
            route_mapping = route_mapping_create.add

            expect(event_repository).to have_received(:record_map_route).with(
              app,
              route,
              user_audit_info,
              route_mapping: route_mapping
            )
          end
        end
      end
    end
  end
end
