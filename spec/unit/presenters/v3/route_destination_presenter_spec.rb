require 'spec_helper'
require 'presenters/v3/route_destination_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe RouteDestinationPresenter do
    subject(:presenter) { RouteDestinationPresenter.new(route_mapping) }
    let(:app) { VCAP::CloudController::AppModel.make }
    let(:route) { VCAP::CloudController::Route.make(space: app.space) }

    let(:route_mapping) do
      VCAP::CloudController::RouteMappingModel.make(
        app: app,
        app_port: 1234,
        route: route,
        process_type: 'web',
        weight: 55
      )
    end

    describe '#to_hash' do
      it 'presents the route mapping as a destination' do
        expect(presenter.to_hash).to eq(
          guid: route_mapping.guid,
          app: {
            guid: route_mapping.app_guid,
            process: {
              type: route_mapping.process_type
            }
          },
          weight: route_mapping.weight,
          port: route_mapping.presented_port,
          protocol: route_mapping.protocol,
          links: {
            destintions: {
              href: "http://api2.vcap.me/v3/routes/#{route.guid}/destinations"
            },
            route: {
              href: "http://api2.vcap.me/v3/routes/#{route.guid}"
            }
          }
        )
      end
    end

    describe '#destination_hash' do
      it 'presents the route mapping as a destination' do
        expect(presenter.destination_hash).to eq(
          guid: route_mapping.guid,
          app: {
            guid: route_mapping.app_guid,
            process: {
              type: route_mapping.process_type
            }
          },
          weight: route_mapping.weight,
          port: route_mapping.presented_port,
          protocol: route_mapping.protocol
        )
      end
    end
  end
end
