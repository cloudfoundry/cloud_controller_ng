require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RouteMappingCreate do
    subject(:route_mapping_create) { RouteMappingCreate.new(user_audit_info, route, process) }

    let(:space) { app.space }
    let(:app) { AppModel.make }
    let(:user_guid) { 'user-guid' }
    let(:user_email) { '1@2.3' }
    let(:user_audit_info) { UserAuditInfo.new(user_email: user_email, user_guid: user_guid) }
    let(:process) { ProcessModel.make(:process, app: app, type: process_type, ports: ports, health_check_type: 'none') }
    let(:process_type) { 'web' }
    let(:ports) { [8080] }
    let(:requested_port) { nil }
    let(:message) { RouteMappingsCreateMessage.new({ relationships: { process: { type: process_type } } }) }
    let(:route_handler) { instance_double(ProcessRouteHandler, update_route_information: nil) }

    before do
      allow(ProcessRouteHandler).to receive(:new).and_return(route_handler)
    end

    describe '#add' do
      let(:route) { Route.make(space: space) }

      it 'maps the route' do
        expect {
          route_mapping = route_mapping_create.add(message)
          expect(route_mapping.route.guid).to eq(route.guid)
          expect(route_mapping.process.guid).to eq(process.guid)
        }.to change { RouteMappingModel.count }.by(1)
      end

      it 'delegates to the route handler to update route information' do
        route_mapping_create.add(message)
        expect(route_handler).to have_received(:update_route_information)
      end

      describe 'recording events' do
        let(:event_repository) { double(Repositories::AppEventRepository) }

        before do
          allow(Repositories::AppEventRepository).to receive(:new).and_return(event_repository)
          allow(event_repository).to receive(:record_map_route)
        end

        it 'creates an event for adding a route to an app' do
          route_mapping = route_mapping_create.add(message)

          expect(event_repository).to have_received(:record_map_route).with(
            app,
            route,
            user_audit_info,
            route_mapping: route_mapping
          )
        end
      end

      context 'when the process is web' do
        let(:process_type) { 'web' }

        context 'dea' do
          let(:process) { ProcessModel.make(diego: false, app: app, type: process_type, health_check_type: 'none') }

          it 'succeeds' do
            route_mapping_create.add(message)
            expect(app.reload.routes).to eq([route])
          end
        end

        context 'diego' do
          let(:process) { ProcessModel.make(diego: true, app: app, type: process_type, ports: [1234, 5678], health_check_type: 'none') }

          it 'succeeds with the default port' do
            mapping = route_mapping_create.add(message)
            expect(app.reload.routes).to eq([route])
            expect(mapping.app_port).to eq(ProcessModel::DEFAULT_HTTP_PORT)
          end
        end

        context 'docker' do
          let(:process) { AppFactory.make(app: app, diego: true, type: process_type, ports: [1234, 5678], health_check_type: 'none', docker_image: 'docker/image') }

          before do
            allow_any_instance_of(AppModel).to receive(:lifecycle_type).and_return(DockerLifecycleDataModel::LIFECYCLE_TYPE)
          end

          it 'succeeds' do
            route_mapping_create.add(message)
            expect(app.reload.routes).to eq([route])
          end
        end
      end

      context 'when a route mapping already exists and a new mapping is requested' do
        before do
          route_mapping_create.add(message)
        end

        context 'for the same process type' do
          it 'does not allow for duplicate route association' do
            expect {
              route_mapping_create.add(message)
            }.to raise_error(RouteMappingCreate::DuplicateRouteMapping, /Duplicate Route Mapping/)
            expect(app.reload.routes).to eq([route])
          end
        end

        context 'for a different process type' do
          let(:worker_process) { ProcessModel.make(:process, app: app, type: 'worker', ports: [8080]) }
          let(:worker_message) { RouteMappingsCreateMessage.new({ relationships: { process: { type: 'worker' } } }) }

          it 'allows a new route mapping' do
            RouteMappingCreate.new(user_audit_info, route, worker_process).add(worker_message)
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
            route_mapping_create.add(message)
          }.to raise_error(RouteMappingCreate::InvalidRouteMapping, 'shizzle')
        end
      end

      context 'when the app and route are in different spaces' do
        let(:route) { Route.make(space: Space.make) }

        it 'raises InvalidRouteMapping' do
          expect {
            route_mapping_create.add(message)
          }.to raise_error(RouteMappingCreate::InvalidRouteMapping, /the app and route must belong to the same space/)
          expect(app.reload.routes).to be_empty
        end
      end
    end
  end
end
