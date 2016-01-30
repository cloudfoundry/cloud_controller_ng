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

    it 'should fetch the associated app, route, space, org, process' do
      returned_app, returned_route, returned_process, returned_space, returned_org = add_route_fetcher.fetch(app.guid, route.guid, 'web')
      expect(returned_app).to eq(app)
      expect(returned_route).to eq(route)
      expect(returned_space).to eq(space)
      expect(returned_org).to eq(org)
      expect(returned_process).to eq(process)
    end

    context 'when the process type is specified' do
      let!(:another_process) { App.make(app_guid: app.guid, type: 'worker') }

      it 'should fetch the correct process' do
        _, _, returned_process, _, _ = add_route_fetcher.fetch(app.guid, route.guid, 'web')
        expect(returned_process.type).to eq('web')
      end
    end

    context 'when app is not found' do
      it 'returns nil' do
        returned_app, returned_route, returned_process, returned_space, returned_org = add_route_fetcher.fetch(nil, nil, 'web')
        expect(returned_app).to be_nil
        expect(returned_route).to be_nil
        expect(returned_space).to be_nil
        expect(returned_org).to be_nil
        expect(returned_process).to be_nil
      end
    end
  end
end
