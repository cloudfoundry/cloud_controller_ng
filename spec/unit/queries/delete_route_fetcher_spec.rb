require 'spec_helper'

module VCAP::CloudController
  describe DeleteRouteFetcher do
    let(:route) { Route.make(space: space) }
    let(:app_model) { AppModel.make(space_guid: space.guid) }
    let(:delete_route_fetcher) { DeleteRouteFetcher.new }
    let(:space) { Space.make }
    let(:different_space) { Space.make }

    before do
      AddRouteToApp.new(app_model).add(route)
    end

    it 'should fetch the associated app and route' do
      returned_app, returned_route = delete_route_fetcher.fetch(app_model.guid, route.guid)
      expect(returned_app).to eq(app_model)
      expect(returned_route).to eq(route)
    end

    it 'should fetch the associated app and route' do
      returned_app, returned_route = delete_route_fetcher.fetch(app_model.guid, route.guid)
      expect(returned_app).to eq(app_model)
      expect(returned_route).to eq(route)
    end

    it 'returns nil if the route is not associated with the app' do
      other_route = Route.make(space: space)
      returned_app, returned_route = delete_route_fetcher.fetch(app_model.guid, other_route.guid)
      expect(returned_app).to eq(app_model)
      expect(returned_route).to eq(nil)
    end
  end
end
