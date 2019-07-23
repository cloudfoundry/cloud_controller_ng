require 'spec_helper'
require 'fetchers/add_route_fetcher'

module VCAP::CloudController
  RSpec.describe AddRouteFetcher do
    let(:space) { Space.make }
    let(:app) { AppModel.make(space_guid: space.guid) }

    let(:route) { Route.make(space: space) }
    let(:route_in_different_space) { Route.make }

    let!(:process) { ProcessModel.make(app_guid: app.guid, type: 'web') }
    let!(:old_process) { ProcessModel.make(app_guid: app.guid, type: 'web', created_at: process.created_at - 1) }
    let!(:another_process) { ProcessModel.make(app_guid: app.guid, type: 'worker') }

    it 'should fetch the associated app, route, space, org, process' do
      returned_app, returned_route, returned_process, returned_space, returned_org =
        AddRouteFetcher.fetch(app_guid: app.guid, process_type: process.type, route_guid: route.guid)
      expect(returned_app).to eq(app)
      expect(returned_route).to eq(route)
      expect(returned_space).to eq(space)
      expect(returned_org).to eq(space.organization)
      expect(returned_process).to eq(process)
    end

    context 'when there is a newer process' do
      let!(:process_3) { ProcessModel.make(app_guid: app.guid, type: 'web', created_at: process.created_at + 1) }

      it 'finds the newest process' do
        returned_app, returned_route, returned_process, returned_space, returned_org =
          AddRouteFetcher.fetch(app_guid: app.guid, process_type: process.type, route_guid: route.guid)
        expect(returned_app).to eq(app)
        expect(returned_route).to eq(route)
        expect(returned_space).to eq(space)
        expect(returned_org).to eq(space.organization)
        expect(returned_process).to eq(process_3)
      end
    end

    context 'when app is not found' do
      it 'returns nil' do
        returned_app, returned_route, returned_process, returned_space, returned_org =
          AddRouteFetcher.fetch(app_guid: 'made-up', process_type: process.type, route_guid: route.guid)
        expect(returned_app).to be_nil
        expect(returned_route).to be_nil
        expect(returned_space).to be_nil
        expect(returned_org).to be_nil
        expect(returned_process).to be_nil
      end
    end
  end
end
