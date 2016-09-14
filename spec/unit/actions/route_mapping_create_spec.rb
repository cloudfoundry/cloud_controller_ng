require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RouteMappingCreate do
    let(:route_mapping_create) { described_class.new(user, user_email, app, route, process, message) }
    let(:space) { app.space }
    let(:app) { AppModel.make }
    let(:user) { double(:user, guid: '7') }
    let(:user_email) { '1@2.3' }
    let(:process) { App.make(:process, app: app, type: process_type, ports: ports, health_check_type: 'none') }
    let(:process_type) { 'web' }
    let(:ports) { [8888] }
    let(:requested_port) { 8888 }
    let(:message) { RouteMappingsCreateMessage.new({ app_port: requested_port, relationships: { process: { type: process_type } } }) }
    let(:route_handler) { instance_double(ProcessRouteHandler, update_route_information: nil) }

    before do
      allow(ProcessRouteHandler).to receive(:new).and_return(route_handler)
    end

    describe '#add' do
      let(:route) { Route.make(space: space) }

      it 'associates the app to the route' do
        route_mapping_create.add
        expect(app.reload.routes).to eq([route])
      end

      it 'delegates to the route handler to update route information' do
        route_mapping_create.add
        expect(route_handler).to have_received(:update_route_information)
      end

      describe 'app_port' do
        context 'docker' do
          let(:process) { AppFactory.make(diego: true, health_check_type: 'none', docker_image: 'docker/image') }
          let(:app) { process.app }
          let(:requested_port) { nil }

          it 'allows null when app_port is not requested' do
            mapping = route_mapping_create.add
            expect(app.reload.routes).to eq([route])
            expect(mapping.app_port).to be_nil
          end
        end

        context 'non-docker' do
          let(:ports) { [1234, 5678] }
          let(:requested_port) { nil }

          it 'defaults to the the default http port when app_port is not requested' do
            mapping = route_mapping_create.add
            expect(app.reload.routes).to eq([route])
            expect(mapping.app_port).to eq(VCAP::CloudController::App::DEFAULT_HTTP_PORT)
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
            user.guid,
            user_email,
            route_mapping: route_mapping
          )
        end
      end

      context 'when the process type does not yet exist' do
        let(:process_type) { 'worker' }
        let(:process) { nil }

        it 'still creates the route mapping' do
          route_mapping_create.add
          expect(app.reload.routes).to eq([route])
          expect(RouteMappingModel.first.process_type).to eq 'worker'
        end
      end

      context 'when the process is web' do
        let(:process_type) { 'web' }

        context 'dea' do
          let(:process) { App.make(diego: false, app: app, type: process_type, health_check_type: 'none') }

          context 'not requesting a port' do
            let(:requested_port) { nil }
            it 'succeeds' do
              route_mapping_create.add
              expect(app.reload.routes).to eq([route])
            end
          end

          context 'requesting a port' do
            let(:requested_port) { 8080 }
            it 'raises' do
              expect {
                route_mapping_create.add
              }.to raise_error(RouteMappingCreate::UnavailableAppPort, /8080 is not available/)
            end
          end
        end

        context 'diego' do
          context 'buildpack' do
            let(:process) { App.make(diego: true, app: app, type: process_type, ports: [1234, 5678], health_check_type: 'none') }

            context 'requesting available port' do
              let(:requested_port) { 5678 }
              it 'succeeds' do
                route_mapping_create.add
                expect(app.reload.routes).to eq([route])
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
              let(:requested_port) { nil }

              it 'succeeds using the first available port from the process' do
                route_mapping_create.add
                expect(app.reload.routes).to eq([route])
              end
            end
          end

          context 'docker' do
            let(:process) { AppFactory.make(diego: true, type: process_type, ports: [1234, 5678], health_check_type: 'none', docker_image: 'docker/image') }
            let(:requested_port) { 8888 }

            it 'does not validate' do
              route_mapping_create.add
              expect(app.reload.routes).to eq([route])
            end
          end
        end
      end

      context 'when the process is not web' do
        let(:process_type) { 'baboon' }

        context 'when no app port is requested' do
          let(:message) { RouteMappingsCreateMessage.new({ relationships: { process: { type: process_type } } }) }

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
          let(:worker_process) { App.make(:process, app: app, type: 'worker', ports: [8888]) }
          let(:worker_message) { RouteMappingsCreateMessage.new({ app_port: 8888, relationships: { process: { type: 'worker' } } }) }

          it 'allows a new route mapping' do
            described_class.new(user, user_email, app, route, worker_process, worker_message).add
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
    end
  end
end
