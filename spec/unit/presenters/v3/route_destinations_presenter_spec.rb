require 'spec_helper'
require 'presenters/v3/route_mapping_presenter'
require 'messages/route_mappings_list_message'

module VCAP::CloudController::Presenters::V3
  RSpec.describe RouteDestinationsPresenter do
    subject(:presenter) { RouteDestinationsPresenter.new(route) }

    let(:app) { VCAP::CloudController::AppModel.make }
    let(:process) { VCAP::CloudController::ProcessModel.make(app: app, type: 'some-type') }
    let(:route) { VCAP::CloudController::Route.make(space: app.space) }
    let!(:route_mapping) do
      VCAP::CloudController::RouteMappingModel.make(
        app: app,
        app_port: 1234,
        route: route,
        process_type: process.type,
        weight: 55
      )
    end

    describe '#to_hash' do
      let(:result) { presenter.to_hash }

      it 'presents the destinations as json' do
        expect(result[:destinations]).to have(1).item
        expect(result[:links]).to include(:self)
        expect(result[:links]).to include(:route)
      end

      it 'should present destinations correctly' do
        expect(result[:destinations][0][:guid]).to eq(route_mapping.guid)
        expect(result[:destinations][0][:app]).to match({
          guid: app.guid,
          process: { type: process.type }
        })
      end

      context 'links' do
        it 'includes correct link hrefs' do
          expect(result[:links][:self][:href]).to eq("#{link_prefix}/v3/routes/#{route_mapping.route_guid}/destinations")
          expect(result[:links][:route][:href]).to eq("#{link_prefix}/v3/routes/#{route_mapping.route_guid}")
        end
      end
    end
  end
end
