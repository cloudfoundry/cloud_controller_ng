require 'spec_helper'
require 'fetchers/route_destinations_list_fetcher'
require 'messages/route_destinations_list_message'

module VCAP::CloudController
  RSpec.describe RouteDestinationsListFetcher do
    subject(:fetcher) { RouteDestinationsListFetcher.new(message: message) }
    let(:message) { RouteDestinationsListMessage.from_params(filters) }
    let(:filters) { {} }

    describe '#fetch_for_route' do
      let!(:route1) { Route.make }
      let!(:route2) { Route.make }

      it 'returns a Sequel::Dataset' do
        results = fetcher.fetch_for_route(route: route1)
        expect(results).to be_a(Sequel::Dataset)
      end

      it 'returns only the destinations for the requested route' do
        dest1_for_route1 = RouteMappingModel.make(route: route1)
        dest2_for_route1 = RouteMappingModel.make(route: route1)

        RouteMappingModel.make(route: route2)

        results = fetcher.fetch_for_route(route: route1).all
        expect(results).to match_array([dest1_for_route1, dest2_for_route1])
      end

      context 'filter' do
        context 'app_guids' do
          let(:space) { Space.make }
          let!(:destination1) { RouteMappingModel.make(app: AppModel.make(space: space), route: route1) }
          let!(:destination2) { RouteMappingModel.make(app: AppModel.make(space: space), route: route1) }
          let(:filters) { { app_guids: [destination1.app.guid] } }

          it 'only returns destinations for the requested app guids' do
            results = fetcher.fetch_for_route(route: route1).all
            expect(results).to match_array([destination1])
            expect(results).not_to include(destination2)
          end
        end

        context 'guids' do
          let(:space) { Space.make }
          let!(:destination1) { RouteMappingModel.make(app: AppModel.make(space: space), route: route1) }
          let!(:destination2) { RouteMappingModel.make(app: AppModel.make(space: space), route: route1) }
          let!(:destination3) { RouteMappingModel.make(app: AppModel.make(space: space), route: route1) }
          let(:filters) { { guids: [destination1.guid, destination2.guid] } }

          it 'only returns destinations for the requested destination guids' do
            results = fetcher.fetch_for_route(route: route1).all
            expect(results).to match_array([destination1, destination2])
            expect(results).not_to include(destination3)
          end
        end
      end
    end
  end
end
