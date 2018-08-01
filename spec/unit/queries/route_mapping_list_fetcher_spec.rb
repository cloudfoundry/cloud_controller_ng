require 'spec_helper'
require 'queries/route_mapping_list_fetcher'

module VCAP::CloudController
  RSpec.describe RouteMappingListFetcher do
    subject(:fetcher) { described_class.new(message: message) }
    let(:message) { RouteMappingsListMessage.new(filters) }
    let(:filters) { {} }

    describe '#fetch_all' do
      it 'returns a dataset' do
        results = fetcher.fetch_all
        expect(results).to be_a(Sequel::Dataset)
      end

      it 'returns all of the processes' do
        route_mapping1 = RouteMappingModel.make
        route_mapping2 = RouteMappingModel.make
        route_mapping3 = RouteMappingModel.make

        expect(fetcher.fetch_all.all).to match_array([route_mapping1, route_mapping2, route_mapping3])
      end

      context 'filter' do
        context 'app_guids' do
          let!(:route_mapping1) { RouteMappingModel.make }
          let!(:route_mapping2) { RouteMappingModel.make }
          let(:filters) { { app_guids: [route_mapping1.app.guid] } }

          it 'only returns matching route mappings' do
            results = fetcher.fetch_all.all
            expect(results).to match_array([route_mapping1])
            expect(results).not_to include(route_mapping2)
          end
        end

        context 'route_guids' do
          let!(:route_mapping1) { RouteMappingModel.make }
          let!(:route_mapping2) { RouteMappingModel.make }
          let(:filters) { { route_guids: [route_mapping1.route.guid] } }

          it 'only returns matching route mappings' do
            results = fetcher.fetch_all.all
            expect(results).to match_array([route_mapping1])
            expect(results).not_to include(route_mapping2)
          end
        end
      end
    end

    describe '#fetch_for_spaces' do
      it 'returns a Sequel::Dataset' do
        results = fetcher.fetch_for_spaces(space_guids: [])
        expect(results).to be_a(Sequel::Dataset)
      end

      it 'returns only the route_mappings in spaces requested' do
        space1                   = Space.make
        app_in_space1            = AppModel.make(space: space1)
        route_mapping1_in_space1 = RouteMappingModel.make(app: app_in_space1)
        route_mapping2_in_space1 = RouteMappingModel.make(app: app_in_space1)

        space2                   = Space.make
        app_in_space2            = AppModel.make(space: space2)
        route_mapping1_in_space2 = RouteMappingModel.make(app: app_in_space2)

        RouteMappingModel.make

        results = fetcher.fetch_for_spaces(space_guids: [space1.guid, space2.guid]).all
        expect(results).to match_array([route_mapping1_in_space1, route_mapping2_in_space1, route_mapping1_in_space2])
      end

      context 'filter' do
        context 'app_guids' do
          let(:space) { Space.make }
          let!(:route_mapping1) { RouteMappingModel.make(app: AppModel.make(space: space)) }
          let!(:route_mapping2) { RouteMappingModel.make(app: AppModel.make(space: space)) }
          let(:filters) { { app_guids: [route_mapping1.app.guid] } }

          it 'only returns matching route mappings' do
            results = fetcher.fetch_for_spaces(space_guids: [space.guid]).all
            expect(results).to match_array([route_mapping1])
            expect(results).not_to include(route_mapping2)
          end
        end

        context 'route_guids' do
          let(:space) { Space.make }
          let!(:route_mapping1) { RouteMappingModel.make(app: AppModel.make(space: space)) }
          let!(:route_mapping2) { RouteMappingModel.make(app: AppModel.make(space: space)) }
          let(:filters) { { route_guids: [route_mapping1.route.guid] } }

          it 'only returns matching route mappings' do
            results = fetcher.fetch_for_spaces(space_guids: [space.guid]).all
            expect(results).to match_array([route_mapping1])
            expect(results).not_to include(route_mapping2)
          end
        end
      end
    end

    describe '#fetch_for_app' do
      let(:app) { AppModel.make }

      it 'returns a Sequel::Dataset' do
        returned_app, results = fetcher.fetch_for_app(app_guid: app.guid)
        expect(results).to be_a(Sequel::Dataset)
        expect(returned_app.guid).to eq(app.guid)
      end

      it 'only returns route mappings for that app' do
        route_mapping_1 = RouteMappingModel.make(app: app)
        route_mapping_2 = RouteMappingModel.make(app: app)
        RouteMappingModel.make

        _app, results = fetcher.fetch_for_app(app_guid: app.guid)

        expect(results.all).to match_array([route_mapping_1, route_mapping_2])
      end

      context 'filter' do
        context 'app_guids' do
          let(:space) { Space.make }
          let!(:route_mapping1) { RouteMappingModel.make(app: AppModel.make(space: space)) }
          let!(:route_mapping2) { RouteMappingModel.make(app: AppModel.make(space: space)) }
          let(:filters) { { app_guids: [route_mapping1.app.guid, route_mapping2.app.guid] } }

          it 'only returns matching route mappings' do
            _returned_app, results = fetcher.fetch_for_app(app_guid: route_mapping1.app.guid)
            expect(results.all).to match_array([route_mapping1])
            expect(results.all).not_to include(route_mapping2)
          end
        end

        context 'route_guids' do
          let(:space) { Space.make }
          let!(:route_mapping1) { RouteMappingModel.make(app: AppModel.make(space: space)) }
          let!(:route_mapping2) { RouteMappingModel.make(app: AppModel.make(space: space)) }
          let(:filters) { { route_guids: [route_mapping1.route.guid, route_mapping2.route.guid] } }

          it 'only returns matching route mappings' do
            _returned_app, results = fetcher.fetch_for_app(app_guid: route_mapping1.app.guid)
            expect(results.all).to match_array([route_mapping1])
            expect(results.all).not_to include(route_mapping2)
          end
        end
      end
    end
  end
end
