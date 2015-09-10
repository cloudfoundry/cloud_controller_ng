require 'spec_helper'

module VCAP::CloudController
  describe RemoveRouteFromApp do
    let(:remove_route_from_app) { RemoveRouteFromApp.new(app) }
    let(:space) { Space.make }
    let(:app) { AppModel.make(space: space) }

    describe '#remove' do
      let(:route) { Route.make(space: space) }

      it 'removes the route from the app' do
        AppModelRoute.create(app: app, route: route, type: 'web')
        remove_route_from_app.remove(route)
        expect(app.reload.routes).to be_empty
      end

      context 'when a web process is present' do
        let!(:process) { AppFactory.make(app: app, space: space, type: 'web') }
        before do
          AddRouteToApp.new(nil, nil).add(app, route, process)
          expect(process.reload.routes).to eq([route])
        end

        it 'removes the route from the web process' do
          remove_route_from_app.remove(route)
          expect(process.reload.routes).to be_empty
        end

        it 'notifies the dea if the process is started and staged' do
          process.update(package_state: 'STAGED')
          process.update(state: 'STARTED')
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

        context 'recording events' do
          let(:user) { User.make }
          let(:user_email) { 'user_email' }
          let(:event_repository) { double(Repositories::Runtime::AppEventRepository) }

          before do
            allow(Repositories::Runtime::AppEventRepository).to receive(:new).and_return(event_repository)
            allow(event_repository).to receive(:record_unmap_route)
          end

          it 'records an event for un mapping a route to an app' do
            allow(SecurityContext).to receive(:current_user).and_return(user)
            allow(SecurityContext).to receive(:current_user_email).and_return(user_email)
            expect(event_repository).to receive(:record_unmap_route).with(
              app,
              route,
              user.guid,
              user_email,
            )

            remove_route_from_app.remove(route)
          end
        end
      end
    end
  end
end
