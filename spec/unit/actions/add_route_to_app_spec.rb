require 'spec_helper'

module VCAP::CloudController
  describe AddRouteToApp do
    let(:add_route_to_app) { AddRouteToApp.new(user, user_email) }
    let(:space) { Space.make }
    let(:app) { AppModel.make }
    let(:user) { double(:user, guid: '7') }
    let(:user_email) { '1@2.3' }

    describe '#add' do
      let(:route) { Route.make(space: space) }

      it 'associates the app to the route' do
        add_route_to_app.add(app, route, nil)
        expect(app.reload.routes).to eq([route])
      end

      it 'does not allow for duplicate route association' do
        add_route_to_app.add(app, route, nil)
        expect {}
        add_route_to_app.add(app, route, nil)
        expect(app.reload.routes).to eq([route])
      end

      context 'when a web process is present' do
        let!(:process) { AppFactory.make(app_guid: app.guid, space: space) }

        it 'associates the route to the web process' do
          add_route_to_app.add(app, route, process)
          expect(process.reload.routes).to eq([route])
        end

        it 'notifies the dea if the process is started and staged' do
          process.update(state: 'STARTED')
          process.update(package_state: 'STAGED')
          expect(Dea::Client).to receive(:update_uris).with(process)
          add_route_to_app.add(app, route, process)
          expect(process.reload.routes).to eq([route])
        end

        it 'does not notify the dea if the process not started' do
          process.update(state: 'STOPPED')
          process.update(package_state: 'STAGED')
          expect(Dea::Client).not_to receive(:update_uris).with(process)
          add_route_to_app.add(app, route, process)
          expect(process.reload.routes).to eq([route])
        end

        it 'does not notify the dea if the process not staged' do
          process.update(state: 'STARTED')
          process.update(package_state: 'PENDING')
          expect(Dea::Client).not_to receive(:update_uris).with(process)
          add_route_to_app.add(app, route, process)
          expect(process.reload.routes).to eq([route])
        end

        context 'recording events' do
          let(:event_repository) { double(Repositories::Runtime::AppEventRepository) }

          before do
            allow(Repositories::Runtime::AppEventRepository).to receive(:new).and_return(event_repository)
            allow(event_repository).to receive(:record_map_route)
          end

          it 'creates an event for adding a route to an app' do
            expect(event_repository).to receive(:record_map_route).with(
              app,
              route,
              user.guid,
              user_email,
            )

            add_route_to_app.add(app, route, nil)
          end
        end

        context 'when the mapping is invalid' do
          before do
            allow(AppModelRoute).to receive(:create).and_raise(Sequel::ValidationFailed.new('shizzle'))
          end

          it 'raises an InvalidRouteMapping error' do
            expect {
              add_route_to_app.add(app, route, nil)
            }.to raise_error(AddRouteToApp::InvalidRouteMapping, 'shizzle')
          end
        end
      end
    end
  end
end
