require 'spec_helper'
require 'queries/route_mapping_list_fetcher'

module VCAP::CloudController
  describe RouteMappingListFetcher do
    let(:space) { Space.make }
    let(:app) { AppModel.make(space_guid: space.guid) }
    let(:other_app) { AppModel.make(space_guid: space.guid) }

    let!(:route_mapping_1) { RouteMappingModel.make(app: app) }
    let!(:route_mapping_2) { RouteMappingModel.make(app: app) }
    let!(:other_route_mapping) { RouteMappingModel.make(app: other_app) }

    let(:pagination_options) { PaginationOptions.new({}) }
    subject(:fetcher) { described_class.new }

    describe '#fetch' do
      it 'returns a PaginatedResult' do
        results = fetcher.fetch(pagination_options, app.guid)
        expect(results).to be_a(PaginatedResult)
      end

      it 'only returns route mappings for that app' do
        results = fetcher.fetch(pagination_options, app.guid).records

        expect(results).to match_array([route_mapping_1, route_mapping_2])
      end
    end
  end
end
