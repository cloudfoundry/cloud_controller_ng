require 'spec_helper'

module VCAP::CloudController
  describe AddRouteFetcher do
    let(:route) { Route.make(space: space) }
    let(:route_in_different_space) { Route.make(space: different_space) }
    let(:app_model) { AppModel.make(space_guid: space.guid) }
    let(:add_route_fetcher) { AddRouteFetcher.new }
    let(:space) { Space.make }
    let(:different_space) { Space.make }

    it 'should fetch the associated app and route' do
      returned_app, returned_route = add_route_fetcher.fetch(app_model.guid, route.guid)
      expect(returned_app).to eq(app_model)
      expect(returned_route).to eq(route)
    end

    it 'works even if the org is suspended' do
      space.organization.update(status: 'suspended')
      returned_app, returned_route = add_route_fetcher.fetch(app_model.guid, route.guid)
      expect(returned_app).to eq(app_model)
      expect(returned_route).to eq(route)
    end

    context 'when the app and the route are not on the same space' do
      it 'returns a nil route' do
        returned_app, returned_route = add_route_fetcher.fetch(app_model.guid, route_in_different_space.guid)
        expect(returned_app).to eq(app_model)
        expect(returned_route).to eq(nil)
      end
    end
  end
end
