require 'spec_helper'

module VCAP::CloudController
  RSpec.describe AddRouteFetcher do
    subject(:fetcher) { AddRouteFetcher.new }

    let(:space) { Space.make }
    let(:app) { AppModel.make(space_guid: space.guid) }

    let(:route) { Route.make(space: space) }
    let(:route_in_different_space) { Route.make }

    let(:process) { App.make(app_guid: app.guid, type: 'web') }
    let!(:another_process) { App.make(app_guid: app.guid, type: 'worker') }

    let(:message) do
      RouteMappingsCreateMessage.new(
        {
          relationships: {
            app:     { guid: app.guid },
            route:   { guid: route.guid },
            process: { type: process.type }
          }
        }
      )
    end

    it 'should fetch the associated app, route, space, org, process' do
      returned_app, returned_route, returned_process, returned_space, returned_org = fetcher.fetch(message)
      expect(returned_app).to eq(app)
      expect(returned_route).to eq(route)
      expect(returned_space).to eq(space)
      expect(returned_org).to eq(space.organization)
      expect(returned_process).to eq(process)
    end

    context 'when app is not found' do
      let(:message) do
        RouteMappingsCreateMessage.new(
          {
            relationships: {
              app:     { guid: 'made-up' },
              route:   { guid: route.guid },
              process: { type: process.type }
            }
          }
        )
      end

      it 'returns nil' do
        returned_app, returned_route, returned_process, returned_space, returned_org = fetcher.fetch(message)
        expect(returned_app).to be_nil
        expect(returned_route).to be_nil
        expect(returned_space).to be_nil
        expect(returned_org).to be_nil
        expect(returned_process).to be_nil
      end
    end
  end
end
