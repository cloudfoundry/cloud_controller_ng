require 'spec_helper'
require 'presenters/v3/route_mapping_presenter'
require 'messages/route_mappings_list_message'

module VCAP::CloudController
  describe RouteMappingPresenter do
    subject(:presenter) { described_class.new }

    let(:route_mapping) do
      RouteMappingModel.make(
        app:          app,
        route:        route,
        process_type: process.type,
        created_at:   Time.at(1),
        updated_at:   Time.at(2),
      )
    end
    let(:app) { AppModel.make }
    let(:process) { App.make(space: app.space, app_guid: app.guid, type: 'some-type') }
    let(:route) { Route.make(space: app.space) }

    describe '#present_json' do
      it 'presents the route_mapping as json' do
        json_result = presenter.present_json(route_mapping)
        result      = MultiJson.load(json_result)

        expect(result['guid']).to eq(route_mapping.guid)
        expect(result['created_at']).to eq('1970-01-01T00:00:01Z')
        expect(result['updated_at']).to eq('1970-01-01T00:00:02Z')
        expect(result['links']).to include('self')
        expect(result['links']).to include('app')
        expect(result['links']).to include('route')
        expect(result['links']).to include('process')
      end

      context 'links' do
        it 'includes correct link hrefs' do
          json_result = presenter.present_json(route_mapping)
          result      = MultiJson.load(json_result)

          expect(result['links']['self']['href']).to eq("/v3/route_mappings/#{route_mapping.guid}")
          expect(result['links']['app']['href']).to eq("/v3/apps/#{app.guid}")
          expect(result['links']['route']['href']).to eq("/v2/routes/#{route_mapping.route.guid}")
          expect(result['links']['process']['href']).to eq("/v3/apps/#{app.guid}/processes/some-type")
        end

        context 'when the process is gone' do
          let(:route_mapping) do
            RouteMappingModel.make(process_type: nil)
          end

          it 'has a null link for process' do
            json_result = presenter.present_json(route_mapping)
            result      = MultiJson.load(json_result)

            expect(result['links']['process']).to be_nil
          end
        end
      end
    end

    describe '#present_json_list' do
      let(:pagination_presenter) { instance_double(PaginationPresenter, present_pagination_hash: 'pagination_stuff') }
      let(:options) { { page: 1, per_page: 2 } }
      let(:app) { AppModel.make }
      let(:route_mapping_1) { RouteMappingModel.make(app: app) }
      let(:route_mapping_2) { RouteMappingModel.make(app: app) }
      let(:presenter) { RouteMappingPresenter.new(pagination_presenter) }
      let(:route_mappings) { [route_mapping_1, route_mapping_2] }
      let(:total_results) { 2 }
      let(:paginated_result) { PaginatedResult.new(route_mappings, total_results, PaginationOptions.new(options)) }

      it 'presents the route mappings as a json array under resources' do
        json_result = presenter.present_json_list(paginated_result, "/v3/apps/#{app.guid}/route_mappings")
        result = MultiJson.load(json_result)
        guids = result['resources'].collect { |route_mapping_json| route_mapping_json['guid'] }

        expect(guids).to eq([route_mapping_1.guid, route_mapping_2.guid])
      end
    end
  end
end
