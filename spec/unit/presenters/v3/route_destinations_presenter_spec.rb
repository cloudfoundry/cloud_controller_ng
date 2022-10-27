require 'spec_helper'
require 'presenters/v3/route_destination_presenter'
require 'messages/route_destinations_list_message'

module VCAP::CloudController::Presenters::V3
  RSpec.describe RouteDestinationsPresenter do
    subject(:presenter) { RouteDestinationsPresenter.new(route.route_mappings, route: route) }

    let!(:app) { VCAP::CloudController::AppModel.make }
    let!(:process) { VCAP::CloudController::ProcessModel.make(app: app, type: 'some-type') }
    let!(:route) { VCAP::CloudController::Route.make(space: app.space) }

    let!(:route_mapping) do
      VCAP::CloudController::RouteMappingModel.make(
        app: app,
        app_port: 1234,
        guid: 'guid-1',
        route: route,
        process_type: process.type,
        weight: 55
      )
    end

    let!(:route_mapping2) do
      VCAP::CloudController::RouteMappingModel.make(
        app: app,
        app_port: 5678,
        guid: 'guid-2',
        route: route,
        process_type: 'other-process',
        weight: 45
      )
    end

    describe '#to_hash' do
      let(:result) { presenter.to_hash }

      it 'presents the destinations as json' do
        expect(result[:destinations]).to have(2).items
        expect(result[:links]).to include(:self)
        expect(result[:links]).to include(:route)
      end

      it 'should present destinations correctly' do
        expect(result[:destinations][0][:guid]).to eq(route_mapping.guid)
        expect(result[:destinations][0][:app]).to match({
          guid: app.guid,
          process: { type: process.type }
        })
        expect(result[:destinations][0][:port]).to eq(route_mapping.app_port)
        expect(result[:destinations][0][:protocol]).to eq(route_mapping.protocol)
        expect(result[:destinations][0][:weight]).to eq(route_mapping.weight)

        expect(result[:destinations][1][:guid]).to eq(route_mapping2.guid)
        expect(result[:destinations][1][:app]).to match({
          guid: app.guid,
          process: { type: 'other-process' }
        })
        expect(result[:destinations][1][:port]).to eq(route_mapping2.app_port)
        expect(result[:destinations][1][:weight]).to eq(route_mapping2.weight)
        expect(result[:destinations][1][:protocol]).to eq(route_mapping2.protocol)
      end
      context 'ordering destinations' do
        let!(:route_mapping) do
          VCAP::CloudController::RouteMappingModel.make(
            app: app,
            app_port: 1234,
            route: route,
            guid: 'guid-2'
          )
        end

        let!(:route_mapping2) do
          VCAP::CloudController::RouteMappingModel.make(
            app: app,
            app_port: 5678,
            route: route,
            guid: 'guid-1'
          )
        end

        it 'sorts the destinations by guid' do
          expect(result[:destinations][0][:guid]).to eq(route_mapping2.guid)
          expect(result[:destinations][1][:guid]).to eq(route_mapping.guid)
        end
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
