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
      end
    end
  end
end
