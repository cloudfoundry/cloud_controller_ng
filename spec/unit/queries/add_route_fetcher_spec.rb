require 'spec_helper'

module VCAP::CloudController
  describe AddRouteFetcher do
    let(:route) { Route.make(space: space) }
    let(:route_in_different_space) { Route.make(space: different_space) }
    let(:app_model) { AppModel.make(space_guid: space.guid) }
    let(:user) { User.make }
    let(:add_route_fetcher) { AddRouteFetcher.new(user) }
    let(:space) { Space.make }
    let(:different_space) { Space.make }

    context 'when the user is admin' do
      let(:user) { User.make(admin: true) }

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
    end

    context 'when the user is a space developer in the apps space' do
      before do
        space.organization.add_user(user)
        space.add_developer(user)
      end

      it 'should fetch the associated app and route' do
        returned_app, returned_route = add_route_fetcher.fetch(app_model.guid, route.guid)
        expect(returned_app).to eq(app_model)
        expect(returned_route).to eq(route)
      end

      it 'returns nil if the org is suspended' do
        space.organization.update(status: 'suspended')
        returned_app, returned_route = add_route_fetcher.fetch(app_model.guid, route.guid)
        expect(returned_app).to eq(nil)
        expect(returned_route).to eq(nil)
      end
    end

    context 'when the user is not a space developer' do
      it 'returns nothing' do
        returned_app, returned_route = add_route_fetcher.fetch(app_model.guid, route.guid)
        expect(returned_app).to eq(nil)
        expect(returned_route).to eq(nil)
      end
    end

    context 'when the app and the route are not on the same space' do
      before do
        space.organization.add_user(user)
        space.add_developer(user)
        different_space.organization.add_user(user)
        different_space.add_developer(user)
      end

      it 'returns a nil route' do
        returned_app, returned_route = add_route_fetcher.fetch(app_model.guid, route_in_different_space.guid)
        expect(returned_app).to eq(app_model)
        expect(returned_route).to eq(nil)
      end
    end
  end
end
