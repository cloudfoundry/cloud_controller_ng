require 'spec_helper'

module VCAP::CloudController
  describe AddRouteToApp do
    let(:add_route_to_app) { AddRouteToApp.new(app) }
    let(:space) { Space.make }
    let(:app) { AppModel.make }

    describe '#add' do
      let(:route) { Route.make(space: space) }

      it 'associates the app to the route' do
        add_route_to_app.add(route)
        expect(app.reload.routes).to eq([route])
      end

      context 'when a web process is present' do
        let!(:process) { AppFactory.make(app_guid: app.guid, space: space) }

        it 'associates the route to the web process' do
          add_route_to_app.add(route)
          expect(process.reload.routes).to eq([route])
        end

        it 'notifies the dea if the process is started and staged' do
          process.update(state: 'STARTED')
          process.update(package_state: 'STAGED')
          expect(Dea::Client).to receive(:update_uris).with(process)
          add_route_to_app.add(route)
          expect(process.reload.routes).to eq([route])
        end

        it 'does not notify the dea if the process not started' do
          process.update(state: 'STOPPED')
          process.update(package_state: 'STAGED')
          expect(Dea::Client).not_to receive(:update_uris).with(process)
          add_route_to_app.add(route)
          expect(process.reload.routes).to eq([route])
        end

        it 'does not notify the dea if the process not staged' do
          process.update(state: 'STARTED')
          process.update(package_state: 'PENDING')
          expect(Dea::Client).not_to receive(:update_uris).with(process)
          add_route_to_app.add(route)
          expect(process.reload.routes).to eq([route])
        end
      end
    end
  end
end
