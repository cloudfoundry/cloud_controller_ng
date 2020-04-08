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
      let(:result) { presenter.to_hash }

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
          port: route_mapping.presented_port
        )
      end
    end
  end
end
