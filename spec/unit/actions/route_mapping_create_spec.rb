require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RouteMappingCreate do
    let(:route_mapping_create) { described_class.new(user, user_email, app, route, process, message) }
    let(:space) { app.space }
    let(:app) { AppModel.make }
    let(:user) { double(:user, guid: '7') }
    let(:user_email) { '1@2.3' }
    let(:process) { App.make(:process, app: app, space: space, type: process_type, ports: ports, health_check_type: 'none') }
    let(:process_type) { 'web' }
    let(:ports) { [8888] }
    let(:requested_port) { 8888 }
    let(:message) { RouteMappingsCreateMessage.new({ app_port: requested_port, relationships: { process: { type: process_type } } }) }

    describe '#add' do
      let(:route) { Route.make(space: space) }

      it 'associates the app to the route' do
        route_mapping_create.add
        expect(app.reload.routes).to eq([route])
      end

      it 'associates the route to the process' do
        route_mapping_create.add
        expect(process.reload.routes).to eq([route])
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
        context 'when no app port is requested' do
          let(:message) { RouteMappingsCreateMessage.new({ relationships: { process: { type: process_type } } }) }
          context 'when the process has an empty array of ports' do
            let(:ports) { [] }
            it 'raises' do
              expect {
                route_mapping_create.add
              }.to raise_error(RouteMappingCreate::InvalidRouteMapping, /8080 is not available/)
            end
          end

          context 'when the process has nil ports' do
            let(:ports) { nil }
            it 'succeeds' do
              route_mapping_create.add
              expect(app.reload.routes).to eq([route])
            end
          end

          context 'when the process has an array of ports' do
            context 'that matches the default port' do
              let(:ports) { [8080] }
              it 'succeeds' do
                route_mapping_create.add
                expect(app.reload.routes).to eq([route])
              end
            end

            context 'that does not match the default port' do
              let(:ports) { [1234] }

              it 'raises' do
                expect {
                  route_mapping_create.add
                }.to raise_error(RouteMappingCreate::InvalidRouteMapping, /8080 is not available/)
              end
            end
          end
        end

        context 'when the default port is requested' do
          let(:requested_port) { 8080 }

          context 'and the process ports are nil' do
            let(:ports) { nil }
            it 'succeeds' do
              route_mapping_create.add
              expect(app.reload.routes).to eq([route])
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
              }.to raise_error(RouteMappingCreate::InvalidRouteMapping, /1234 is not available/)
            end
          end

          context 'when the process has nil ports' do
            let(:ports) { nil }

            it 'raises' do
              expect {
                route_mapping_create.add
              }.to raise_error(RouteMappingCreate::InvalidRouteMapping, /1234 is not available/)
            end
          end

          context 'when the process has an array of ports' do
            context 'that matches the requested port' do
              let(:ports) { [1234, 5678] }

              it 'succeeds' do
                route_mapping_create.add
                expect(app.reload.routes).to eq([route])
              end
            end

            context 'that does not match the requested port' do
              let(:ports) { [5678] }

              it 'raises' do
                expect {
                  route_mapping_create.add
                }.to raise_error(RouteMappingCreate::InvalidRouteMapping, /1234 is not available/)
              end
            end
          end
        end
      end

      context 'when the process is not web' do
        let(:process_type) { 'baboon' }

        context 'when no app port is requested' do
          let(:message) { RouteMappingsCreateMessage.new({ relationships: { process: { type: process_type } } }) }
          context 'when the process has an empty array of ports' do
            let(:ports) { [] }
            it 'raises' do
              expect {
                route_mapping_create.add
              }.to raise_error(RouteMappingCreate::InvalidRouteMapping, /8080 is not available/)
            end
          end

          context 'when the process has nil ports' do
            let(:ports) { nil }
            it 'raises' do
              expect {
                route_mapping_create.add
              }.to raise_error(RouteMappingCreate::InvalidRouteMapping, /8080 is not available/)
            end
          end

          context 'when the process has an array of ports' do
            context 'that matches the default port' do
              let(:ports) { [8080] }
              it 'succeeds' do
                route_mapping_create.add
                expect(app.reload.routes).to eq([route])
              end
            end

            context 'that does not match the default port' do
              let(:ports) { [1234] }

              it 'raises' do
                expect {
                  route_mapping_create.add
                }.to raise_error(RouteMappingCreate::InvalidRouteMapping, /8080 is not available/)
              end
            end
          end
        end

        context 'when the default web port is requested' do
          let(:requested_port) { 8080 }
          context 'when the process has an empty array of ports' do
            let(:ports) { [] }
            it 'raises' do
              expect {
                route_mapping_create.add
              }.to raise_error(RouteMappingCreate::InvalidRouteMapping, /8080 is not available/)
            end
          end

          context 'when the process has nil ports' do
            let(:ports) { nil }
            it 'raises' do
              expect {
                route_mapping_create.add
              }.to raise_error(RouteMappingCreate::InvalidRouteMapping, /8080 is not available/)
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
              }.to raise_error(RouteMappingCreate::InvalidRouteMapping, /1234 is not available/)
            end
          end

          context 'when the process has nil ports' do
            let(:ports) { nil }
            it 'raises' do
              expect {
                route_mapping_create.add
              }.to raise_error(RouteMappingCreate::InvalidRouteMapping, /1234 is not available/)
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
            }.to raise_error(RouteMappingCreate::InvalidRouteMapping, /Duplicate Route Mapping/)
            expect(app.reload.routes).to eq([route])
          end
        end

        context 'for a different process type' do
          let(:worker_process) { App.make(:process, app_guid: app.guid, space: space, type: 'worker', ports: [8888]) }
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
