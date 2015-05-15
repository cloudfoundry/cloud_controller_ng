require 'spec_helper'

module VCAP::CloudController
  describe DeleteRouteFetcher do
    let(:delete_route_fetcher) { DeleteRouteFetcher.new }
    let(:space) { Space.make }
    let(:org) { space.organization }
    let(:app_model) { AppModel.make(space_guid: space.guid) }
    let(:route) { Route.make(space: space) }

    before do
      AddRouteToApp.new(nil, nil).add(app_model, Route.make(space: space), nil)
      AddRouteToApp.new(nil, nil).add(app_model, route, nil)
    end

    it 'fetches the associated app, route, space, org' do
      returned_app, returned_route, returned_space, returned_org = delete_route_fetcher.fetch(app_model.guid, route.guid)
      expect(returned_app).to eq(app_model)
      expect(returned_route).to eq(route)
      expect(returned_space).to eq(space)
      expect(returned_org).to eq(org)
    end

    it 'returns nil if the route is not associated with the app' do
      other_route = Route.make(space: space)
      returned_app, returned_route = delete_route_fetcher.fetch(app_model.guid, other_route.guid)
      expect(returned_app).to eq(app_model)
      expect(returned_route).to eq(nil)
    end
  end
end
