require 'spec_helper'
require 'queries/route_mapping_list_fetcher'

module VCAP::CloudController
  describe RouteMappingListFetcher do
    subject(:fetcher) { described_class.new }
    let(:pagination_options) { PaginationOptions.new({}) }

    describe '#fetch_all' do
      it 'returns a PaginatedResult' do
        results = fetcher.fetch_all(pagination_options: pagination_options)
        expect(results).to be_a(PaginatedResult)
      end

      it 'returns all of the processes' do
        route_mapping1 = RouteMappingModel.make
        route_mapping2 = RouteMappingModel.make
        route_mapping3 = RouteMappingModel.make

        results = fetcher.fetch_all(pagination_options: pagination_options).records
        expect(results).to match_array([route_mapping1, route_mapping2, route_mapping3])
      end
    end

    describe '#fetch_for_spaces' do
      it 'returns a PaginatedResult' do
        results = fetcher.fetch_for_spaces(pagination_options: pagination_options, space_guids: [])
        expect(results).to be_a(PaginatedResult)
      end

      it 'returns only the route_mappings in spaces requested' do
        space1 = Space.make
        app_in_space1 = AppModel.make(space: space1)
        route_mapping1_in_space1 = RouteMappingModel.make(app: app_in_space1)
        route_mapping2_in_space1 = RouteMappingModel.make(app: app_in_space1)

        space2 = Space.make
        app_in_space2 = AppModel.make(space: space2)
        route_mapping1_in_space2 = RouteMappingModel.make(app: app_in_space2)

        RouteMappingModel.make

        results = fetcher.fetch_for_spaces(pagination_options: pagination_options, space_guids: [space1.guid, space2.guid]).records
        expect(results).to match_array([route_mapping1_in_space1, route_mapping2_in_space1, route_mapping1_in_space2])
      end
    end

    describe '#fetch_for_app' do
      let(:app) { AppModel.make }

      it 'returns a PaginatedResult' do
        returned_app, results = fetcher.fetch_for_app(pagination_options: pagination_options, app_guid: app.guid)
        expect(results).to be_a(PaginatedResult)
        expect(returned_app.guid).to eq(app.guid)
      end

      it 'only returns route mappings for that app' do
        route_mapping_1 = RouteMappingModel.make(app: app)
        route_mapping_2 = RouteMappingModel.make(app: app)
        RouteMappingModel.make

        _app, results = fetcher.fetch_for_app(pagination_options: pagination_options, app_guid: app.guid)

        expect(results.records).to match_array([route_mapping_1, route_mapping_2])
      end
    end
  end
end
