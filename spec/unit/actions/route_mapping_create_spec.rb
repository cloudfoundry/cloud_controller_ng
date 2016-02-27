require 'spec_helper'

module VCAP::CloudController
  describe RouteMappingCreate do
    let(:route_mapping_create) { described_class.new(user, user_email) }
    let(:space) { app.space }
    let(:app) { AppModel.make }
    let(:user) { double(:user, guid: '7') }
    let(:user_email) { '1@2.3' }
    let(:process) { AppFactory.make(app_guid: app.guid, space: space) }
    let(:process_type) { process.type }

    describe '#add' do
      let(:route) { Route.make(space: space) }

      it 'associates the app to the route' do
        route_mapping_create.add(app, route, process, process_type)
        expect(app.reload.routes).to eq([route])
      end

      context 'when the process type does not yet exist' do
        it 'still creates the route mapping' do
          route_mapping_create.add(app, route, nil, 'worker')
          expect(app.reload.routes).to eq([route])
          expect(RouteMappingModel.first.process_type).to eq 'worker'
        end
      end

      context 'when a route mapping already exists and a new mapping is requested' do
        before do
          route_mapping_create.add(app, route, process, process_type)
        end

        context 'for the same process type' do
          it 'does not allow for duplicate route association' do
            expect {
              route_mapping_create.add(app, route, process, process_type)
            }.to raise_error(RouteMappingCreate::InvalidRouteMapping, /a duplicate route mapping already exists/)
            expect(app.reload.routes).to eq([route])
          end
        end

        context 'for a different process type' do
          let(:worker_process) { AppFactory.make(app_guid: app.guid, space: space, type: 'worker') }

          it 'allows a new route mapping' do
            route_mapping_create.add(app, route, worker_process, 'worker')
            expect(app.reload.routes).to eq([route, route])
          end
        end
      end

      it 'associates the route to the process' do
        route_mapping_create.add(app, route, process, process_type)
        expect(process.reload.routes).to eq([route])
      end

      it 'notifies the dea if the process is started and staged' do
        process.update(state: 'STARTED')
        process.update(package_state: 'STAGED')
        expect(Dea::Client).to receive(:update_uris).with(process)
        route_mapping_create.add(app, route, process, process_type)
        expect(process.reload.routes).to eq([route])
      end

      it 'does not notify the dea if the process not started' do
        process.update(state: 'STOPPED')
        process.update(package_state: 'STAGED')
        expect(Dea::Client).not_to receive(:update_uris).with(process)
        route_mapping_create.add(app, route, process, process_type)
        expect(process.reload.routes).to eq([route])
      end

      it 'does not notify the dea if the process not staged' do
        process.update(state: 'STARTED')
        process.update(package_state: 'PENDING')
        expect(Dea::Client).not_to receive(:update_uris).with(process)
        route_mapping_create.add(app, route, process, process_type)
        expect(process.reload.routes).to eq([route])
      end

      describe 'recording events' do
        let(:event_repository) { double(Repositories::Runtime::AppEventRepository) }

        before do
          allow(Repositories::Runtime::AppEventRepository).to receive(:new).and_return(event_repository)
          allow(event_repository).to receive(:record_map_route)
        end

        it 'creates an event for adding a route to an app' do
          route_mapping = route_mapping_create.add(app, route, process, process_type)

          expect(event_repository).to have_received(:record_map_route).with(
            app,
            route,
            user.guid,
            user_email,
            route_mapping: route_mapping
          )
        end
      end

      context 'when the mapping is invalid' do
        before do
          allow(RouteMappingModel).to receive(:create).and_raise(Sequel::ValidationFailed.new('shizzle'))
        end

        it 'raises an InvalidRouteMapping error' do
          expect {
            route_mapping_create.add(app, route, process, process_type)
          }.to raise_error(RouteMappingCreate::InvalidRouteMapping, 'shizzle')
        end
      end

      context 'when the app and route are in different spaces' do
        let(:route) { Route.make(space: Space.make) }

        it 'raises InvalidRouteMapping' do
          expect {
            route_mapping_create.add(app, route, process, process_type)
          }.to raise_error(RouteMappingCreate::InvalidRouteMapping, /the app and route must belong to the same space/)
          expect(app.reload.routes).to be_empty
        end
      end
    end
  end
end
