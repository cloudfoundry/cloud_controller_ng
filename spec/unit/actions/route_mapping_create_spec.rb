require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RouteMappingCreate do
    let(:space) { app.space }
    let(:app) { AppModel.make }
    let(:user_guid) { 'user-guid' }
    let(:user_email) { '1@2.3' }
    let(:user_audit_info) { UserAuditInfo.new(user_email: user_email, user_guid: user_guid) }
    let!(:process1) { ProcessModel.make(:process, app: app, type: process_type, ports: ports, health_check_type: 'none') }
    let!(:process2) { ProcessModel.make(:process, app: app, type: process_type, ports: ports, health_check_type: 'none') }
    let(:process_type) { 'web' }
    let(:ports) { [8080] }
    let(:requested_port) { nil }
    let(:process1_route_handler) { instance_double(ProcessRouteHandler, update_route_information: nil) }
    let(:process2_route_handler) { instance_double(ProcessRouteHandler, update_route_information: nil) }

    before do
      allow(ProcessRouteHandler).to receive(:new).with(process1).and_return(process1_route_handler)
      allow(ProcessRouteHandler).to receive(:new).with(process2).and_return(process2_route_handler)
    end

    describe '#add' do
      let(:route) { Route.make(space: space) }

      it 'maps the route' do
        expect {
          route_mapping = RouteMappingCreate.add(user_audit_info: user_audit_info, route: route, app: app, process_type: process_type)
          expect(route_mapping.route.guid).to eq(route.guid)
          expect(route_mapping.processes.map(&:guid)).to contain_exactly(process1.guid, process2.guid)
          expect(route_mapping.weight).to eq(1)
        }.to change { RouteMappingModel.count }.by(1)
      end

      context 'when a weight is provided' do
        it 'creates the route mapping with the given weight' do
          weight = 5
          route_mapping = RouteMappingCreate.add(user_audit_info: user_audit_info, route: route, app: app, process_type: process_type, weight: weight)
          expect(route_mapping.weight).to eq(5)
        end
      end

      it 'delegates to the route handler to update route information for all processes' do
        RouteMappingCreate.add(user_audit_info: user_audit_info, route: route, app: app, process_type: process_type)
        expect(process1_route_handler).to have_received(:update_route_information)
        expect(process2_route_handler).to have_received(:update_route_information)
      end

      describe 'copilot integration' do
        before do
          allow(Copilot::Adapter).to receive(:map_route)
        end

        it 'delegates to the copilot handler to notify copilot' do
          expect {
            route_mapping = RouteMappingCreate.add(user_audit_info: user_audit_info, route: route, app: app, process_type: process_type)
            expect(Copilot::Adapter).to have_received(:map_route).with(route_mapping)
          }.to change { RouteMappingModel.count }.by(1)
        end
      end

      describe 'recording events' do
        let(:event_repository) { double(Repositories::AppEventRepository) }

        before do
          allow(Repositories::AppEventRepository).to receive(:new).and_return(event_repository)
          allow(event_repository).to receive(:record_map_route)
        end

        it 'creates an event for adding a route to an app' do
          route_mapping = RouteMappingCreate.add(user_audit_info: user_audit_info, route: route, app: app, process_type: process_type)

          expect(event_repository).to have_received(:record_map_route).with(
            app,
            route,
            user_audit_info,
            route_mapping: route_mapping,
            manifest_triggered: false
          )
        end

        context 'when the route mapping create is triggered by applying a manifest' do
          it 'sends manifest_triggered: true to the event repository' do
            route_mapping = RouteMappingCreate.add(user_audit_info: user_audit_info, route: route, app: app, process_type: process_type, manifest_triggered: true)

            expect(event_repository).to have_received(:record_map_route).with(
              app,
              route,
              user_audit_info,
              route_mapping: route_mapping,
              manifest_triggered: true
            )
          end
        end
      end

      context 'when the process is web' do
        let(:process_type) { 'web' }

        let(:process) { ProcessModel.make(diego: true, app: app, type: process_type, ports: [1234, 5678], health_check_type: 'none') }

        it 'succeeds with the default port' do
          mapping = RouteMappingCreate.add(user_audit_info: user_audit_info, route: route, app: app, process_type: process_type)
          expect(app.reload.routes).to eq([route])
          expect(mapping.app_port).to eq(ProcessModel::DEFAULT_HTTP_PORT)
        end

        context 'docker' do
          let(:process) { ProcessModelFactory.make(app: app, diego: true, type: process_type, ports: [1234, 5678], health_check_type: 'none', docker_image: 'docker/image') }

          before do
            allow_any_instance_of(AppModel).to receive(:lifecycle_type).and_return(DockerLifecycleDataModel::LIFECYCLE_TYPE)
          end

          it 'succeeds' do
            RouteMappingCreate.add(user_audit_info: user_audit_info, route: route, app: app, process_type: process_type)
            expect(app.reload.routes).to eq([route])
          end
        end
      end

      context 'when a route mapping already exists and a new mapping is requested' do
        before do
          RouteMappingCreate.add(user_audit_info: user_audit_info, route: route, app: app, process_type: process_type)
        end

        context 'for the same process type' do
          it 'does not allow for duplicate route association' do
            expect {
              RouteMappingCreate.add(user_audit_info: user_audit_info, route: route, app: app, process_type: process_type)
            }.to raise_error(RouteMappingCreate::DuplicateRouteMapping, /Duplicate Route Mapping/)
            expect(app.reload.routes).to eq([route])
          end
        end

        context 'for a different process type' do
          let(:worker_process) { ProcessModel.make(:process, app: app, type: 'worker', ports: [8080]) }
          let(:worker_message) { RouteMappingsCreateMessage.new({ relationships: { process: { type: 'worker' } } }) }
          let(:worker_route_handler) { instance_double(ProcessRouteHandler, update_route_information: nil) }

          before do
            allow(ProcessRouteHandler).to receive(:new).with(worker_process).and_return(worker_route_handler)
          end

          it 'allows a new route mapping' do
            RouteMappingCreate.add(user_audit_info: user_audit_info, route: route, app: app, process_type: worker_process.type)
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
            RouteMappingCreate.add(user_audit_info: user_audit_info, route: route, app: app, process_type: process_type)
          }.to raise_error(RouteMappingCreate::InvalidRouteMapping, 'shizzle')
        end
      end

      context 'when the app and route are in different spaces' do
        let(:route) { Route.make(space: FactoryBot.create(:space)) }

        it 'raises SpaceMismatch' do
          expect {
            RouteMappingCreate.add(user_audit_info: user_audit_info, route: route, app: app, process_type: process_type)
          }.to raise_error { |error|
            expect(error).to be_a(RouteMappingCreate::SpaceMismatch)
            expect(error.message).to match(/#{route.uri}/)
            expect(error.message).to match(/because the route is not in this space/)
          }
          expect(app.reload.routes).to be_empty
        end
      end
    end
  end
end
