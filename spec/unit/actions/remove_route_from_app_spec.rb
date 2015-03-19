require 'spec_helper'

module VCAP::CloudController
  describe RemoveRouteFromApp do
    let(:remove_route_from_app) { RemoveRouteFromApp.new(app) }
    let(:space) { Space.make }
    let(:app) { AppModel.make }
    let!(:process) { AppFactory.make(app_guid: app.guid, space: space) }

    describe '#remove' do
      let(:route) { Route.make(space: space) }
      before do
        AddRouteToApp.new(app).add(route)
      end

      it 'removes the route from the app' do
        remove_route_from_app.remove(route)
        expect(app.reload.routes).to be_empty
      end

      context 'when a web process is present' do
        it 'removes the route from the web process' do
          remove_route_from_app.remove(route)
          expect(process.reload.routes).to be_empty
        end

        it 'notifies the dea if the process is started and staged' do
          process.update(state: 'STARTED')
          process.update(package_state: 'STAGED')
          expect(Dea::Client).to receive(:update_uris).with(process)
          remove_route_from_app.remove(route)
          expect(process.reload.routes).to be_empty
        end

        it 'does not notify the dea if the process not started' do
          process.update(state: 'STOPPED')
          process.update(package_state: 'STAGED')
          expect(Dea::Client).not_to receive(:update_uris).with(process)
          remove_route_from_app.remove(route)
          expect(process.reload.routes).to be_empty
        end

        it 'does not notify the dea if the process not staged' do
          process.update(state: 'STARTED')
          process.update(package_state: 'PENDING')
          expect(Dea::Client).not_to receive(:update_uris).with(process)
          remove_route_from_app.remove(route)
          expect(process.reload.routes).to be_empty
        end
      end
    end
  end
end
