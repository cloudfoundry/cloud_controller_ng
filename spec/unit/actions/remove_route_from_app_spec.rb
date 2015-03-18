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
      end
    end
  end
end
