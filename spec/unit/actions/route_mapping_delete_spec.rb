require 'spec_helper'

module VCAP::CloudController
  describe RouteMappingDelete do
    subject(:route_mapping_delete) { described_class.new(user, user_email) }
    let(:user) { User.make }
    let(:user_email) { 'user_email' }
    let(:space) { Space.make }
    let(:app) { AppModel.make(space: space) }
    let(:route) { Route.make(space: space) }
    let!(:route_mapping) { RouteMappingModel.create(app: app, route: route, process_type: 'other') }

    describe '#delete' do
      it 'can delete a single route mapping' do
        route_mapping_delete.delete(route_mapping)
        expect(route_mapping.exists?).to be_falsey
      end

      it 'can delete multiple route mappings' do
        route_mapping_2 = RouteMappingModel.make app: app
        route_mapping_delete.delete([route_mapping, route_mapping_2])
        expect(route_mapping.exists?).to be_falsey
        expect(route_mapping_2.exists?).to be_falsey
      end

      it 'deletes the route from the app' do
        expect(app.reload.routes).not_to be_empty
        route_mapping_delete.delete(route_mapping)
        expect(app.reload.routes).to be_empty
      end

      context 'when a mapped process is present' do
        let(:process) { AppFactory.make(app: app, space: space, type: 'other') }

        before do
          process.add_route(route)
        end

        it 'deletes the mapped route from the mapped process' do
          expect(process.reload.routes).not_to be_empty
          route_mapping_delete.delete(route_mapping)
          expect(process.reload.routes).to be_empty
        end

        it 'notifies the dea if the process is started and staged' do
          expect(process.reload.routes).not_to be_empty
          process.update(package_state: 'STAGED')
          process.update(state: 'STARTED')
          expect(Dea::Client).to receive(:update_uris).with(process)
          route_mapping_delete.delete(route_mapping)
          expect(process.reload.routes).to be_empty
        end

        it 'does not notify the dea if the process not started' do
          expect(process.reload.routes).not_to be_empty
          process.update(state: 'STOPPED')
          process.update(package_state: 'STAGED')
          expect(Dea::Client).not_to receive(:update_uris).with(process)
          route_mapping_delete.delete(route_mapping)
          expect(process.reload.routes).to be_empty
        end

        it 'does not notify the dea if the process not staged' do
          expect(process.reload.routes).not_to be_empty
          process.update(state: 'STARTED')
          process.update(package_state: 'PENDING')
          expect(Dea::Client).not_to receive(:update_uris).with(process)
          route_mapping_delete.delete(route_mapping)
          expect(process.reload.routes).to be_empty
        end

        context 'recording events' do
          let(:event_repository) { instance_double(Repositories::Runtime::AppEventRepository) }

          before do
            allow(Repositories::Runtime::AppEventRepository).to receive(:new).and_return(event_repository)
            allow(event_repository).to receive(:record_unmap_route)
          end

          it 'records an event for un mapping a route to an app' do
            route_mapping_delete.delete(route_mapping)

            expect(event_repository).to have_received(:record_unmap_route).with(
              app,
              route,
              user.guid,
              user_email,
              route_mapping: route_mapping
            )
          end
        end
      end
    end
  end
end
