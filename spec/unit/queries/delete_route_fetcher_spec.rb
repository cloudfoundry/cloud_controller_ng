require 'spec_helper'

module VCAP::CloudController
  describe DeleteRouteFetcher do
    let(:route) { Route.make(space: space) }
    let(:app_model) { AppModel.make(space_guid: space.guid) }
    let(:user) { User.make }
    let(:delete_route_fetcher) { DeleteRouteFetcher.new(user) }
    let(:space) { Space.make }
    let(:different_space) { Space.make }

    before do
      AddRouteToApp.new(app_model).add(route)
    end

    context 'when the user is admin' do
      let(:user) { User.make(admin: true) }

      it 'should fetch the associated app and route' do
        returned_app, returned_route = delete_route_fetcher.fetch(app_model.guid, route.guid)
        expect(returned_app).to eq(app_model)
        expect(returned_route).to eq(route)
      end

      it 'works even if the org is suspended' do
        space.organization.update(status: 'suspended')
        returned_app, returned_route = delete_route_fetcher.fetch(app_model.guid, route.guid)
        expect(returned_app).to eq(app_model)
        expect(returned_route).to eq(route)
      end
    end

    context 'when the user is a space developer in the apps space' do
      before do
        space.organization.add_user(user)
        space.add_developer(user)
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

      it 'returns nil if the org is suspended' do
        space.organization.update(status: 'suspended')
        returned_app, returned_route = delete_route_fetcher.fetch(app_model.guid, route.guid)
        expect(returned_app).to eq(nil)
        expect(returned_route).to eq(nil)
      end
    end

    context 'when the user is not a space developer' do
      it 'returns nothing' do
        returned_app, returned_route = delete_route_fetcher.fetch(app_model.guid, route.guid)
        expect(returned_app).to eq(nil)
        expect(returned_route).to eq(nil)
      end
    end
  end
end
