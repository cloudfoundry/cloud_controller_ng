require 'spec_helper'

module VCAP::CloudController
  describe AddRouteFetcher do
    let(:add_route_fetcher) { AddRouteFetcher.new }
    let(:route) { Route.make(space: space) }
    let(:route_in_different_space) { Route.make }
    let(:app) { AppModel.make(space_guid: space.guid) }
    let(:space) { Space.make }
    let(:org) { space.organization }
    let!(:process) { App.make(app_guid: app.guid, type: 'web') }

    it 'should fetch the associated app, route, space, org, web process' do
      returned_app, returned_route, returned_process, returned_space, returned_org = add_route_fetcher.fetch(app.guid, route.guid)
      expect(returned_app).to eq(app)
      expect(returned_route).to eq(route)
      expect(returned_space).to eq(space)
      expect(returned_org).to eq(org)
      expect(returned_process).to eq(process)
    end

    context 'when the app and the route are not on the same space' do
      it 'returns a nil route' do
        returned_app, returned_route, _, returned_space, returned_org = add_route_fetcher.fetch(app.guid, route_in_different_space.guid)
        expect(returned_app).to eq(app)
        expect(returned_route).to eq(nil)
        expect(returned_space).to eq(space)
        expect(returned_org).to eq(org)
      end
    end
  end
end
