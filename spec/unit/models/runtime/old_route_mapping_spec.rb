require 'spec_helper'

module VCAP::CloudController
  describe VCAP::CloudController::OldRouteMapping, type: :model do
    it 'reads the old apps_routes table' do
      app = AppFactory.make
      route = Route.make(space: app.space)
      app.add_route(route)

      mapping = OldRouteMapping.find(app: app, route: route)
      expect(mapping).not_to be_nil
      expect(mapping.app_id).to eq(app.id)
      expect(mapping.route_id).to eq(route.id)
    end
  end
end