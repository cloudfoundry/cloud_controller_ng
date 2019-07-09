require 'spec_helper'
require 'messages/routes_list_message'
require 'fetchers/route_fetcher'

module VCAP::CloudController
  RSpec.describe RouteFetcher do
    describe '.fetch' do
      before do
        Route.dataset.destroy
      end

      let!(:space1) { Space.make }
      let!(:space2) { Space.make }
      let!(:domain1) { PrivateDomain.make(owning_organization: space1.organization) }
      let!(:domain2) { PrivateDomain.make(owning_organization: space2.organization) }
      let!(:route1) { Route.make(host: 'host1', path: '/path1', space: space1, domain: domain1) }
      let!(:route2) { Route.make(host: 'host2', path: '/path2', space: space1, domain: domain1) }
      let!(:route3) { Route.make(host: 'host2', path: '/path1', space: space2, domain: domain2) }

      let(:message) do
        RoutesListMessage.from_params(routes_filter)
      end

      context 'when fetching routes by hosts' do
        context 'when there is a matching route' do
          let(:routes_filter) { { hosts: 'host2' } }

          it 'only returns the matching route' do
            results = RouteFetcher.fetch(message, [route1.guid, route2.guid]).all
            expect(results.length).to eq(1)
            expect(results[0].guid).to eq(route2.guid)
          end
        end

        context 'when there is no matching route' do
          let(:routes_filter) { { hosts: 'unknown-host' } }

          it 'returns no routes' do
            results = RouteFetcher.fetch(message, [route1.guid, route2.guid]).all
            expect(results.length).to eq(0)
          end
        end
      end

      context 'when fetching routes by paths' do
        context 'when there is a matching route' do
          let(:routes_filter) { { paths: '/path1' } }

          it 'only returns the matching route' do
            results = RouteFetcher.fetch(message, [route1.guid, route2.guid]).all
            expect(results.length).to eq(1)
            expect(results[0].guid).to eq(route1.guid)
          end
        end

        context 'when there is no matching route' do
          let(:routes_filter) { { paths: 'unknown-path' } }

          it 'returns no routes' do
            results = RouteFetcher.fetch(message, [route1.guid, route2.guid]).all
            expect(results.length).to eq(0)
          end
        end
      end

      context 'when fetching routes by space_guids' do
        context 'when there is a matching route' do
          let(:routes_filter) { { space_guids: space1.guid } }

          it 'only returns the matching route' do
            results = RouteFetcher.fetch(message, [route2.guid, route3.guid]).all
            expect(results.length).to eq(1)
            expect(results[0].guid).to eq(route2.guid)
          end
        end

        context 'when there is no matching route' do
          let(:routes_filter) { { space_guids: '???' } }

          it 'returns no routes' do
            results = RouteFetcher.fetch(message, [route2.guid, route3.guid]).all
            expect(results.length).to eq(0)
          end
        end
      end

      context 'when fetching routes by organization_guids' do
        context 'when there is a matching route' do
          let(:routes_filter) { { organization_guids: space1.organization.guid } }

          it 'only returns the matching route' do
            results = RouteFetcher.fetch(message, [route2.guid, route3.guid]).all
            expect(results.length).to eq(1)
            expect(results[0].guid).to eq(route2.guid)
          end
        end

        context 'when there is no matching route' do
          let(:routes_filter) { { organization_guids: '???' } }

          it 'returns no routes' do
            results = RouteFetcher.fetch(message, [route2.guid, route3.guid]).all
            expect(results.length).to eq(0)
          end
        end
      end

      context 'when fetching routes by domain_guids' do
        context 'when there is a matching route' do
          let(:routes_filter) { { domain_guids: domain2.guid } }

          it 'only returns the matching route' do
            results = RouteFetcher.fetch(message, [route2.guid, route3.guid]).all
            expect(results.length).to eq(1)
            expect(results[0].guid).to eq(route3.guid)
          end
        end

        context 'when there is no matching route' do
          let(:routes_filter) { { domain_guids: '???' } }

          it 'returns no routes' do
            results = RouteFetcher.fetch(message, [route2.guid, route3.guid]).all
            expect(results.length).to eq(0)
          end
        end
      end

      context 'when fetching routes by label selector' do
        let!(:route_label) do
          VCAP::CloudController::RouteLabelModel.make(resource_guid: route1.guid, key_name: 'dog', value: 'scooby-doo')
        end

        let!(:sad_route_label) do
          VCAP::CloudController::RouteLabelModel.make(resource_guid: route2.guid, key_name: 'dog', value: 'poodle')
        end

        let!(:happiest_route_label) do
          VCAP::CloudController::RouteLabelModel.make(resource_guid: route3.guid, key_name: 'dog', value: 'chihuahua')
        end

        let(:results) { RouteFetcher.fetch(message, [route1.guid, route3.guid]).all }

        context 'only the label_selector is present' do
          let(:results) { RouteFetcher.fetch(message, [route1.guid]).all }

          let(:message) {
            RoutesListMessage.from_params({ 'label_selector' => 'dog in (chihuahua,scooby-doo)' })
          }
          it 'returns only the route whose label matches' do
            expect(results.length).to eq(1)
            expect(results[0]).to eq(route1)
          end
        end

        context 'and other filters are present' do
          let(:message) {
            RoutesListMessage.from_params({ paths: '/path1', hosts: 'host2', 'label_selector' => 'dog in (chihuahua,scooby-doo)' })
          }

          it 'returns the desired app' do
            expect(results.length).to eq(1)
            expect(results[0]).to eq(route3)
          end
        end
      end

      context 'when fetching routes for an app' do
        let(:app_model) { AppModel.make(space: space1) }
        let!(:destination1) { RouteMappingModel.make(app: app_model, route: route1, process_type: 'web') }
        let!(:destination2) { RouteMappingModel.make(app: app_model, route: route2, process_type: 'worker') }
        let(:message) { RoutesListMessage.from_params({}).for_app_guid(app_model.guid) }

        it 'only returns routes that are mapped to the app' do
          results = RouteFetcher.fetch(message, Route.all.map(&:guid)).all
          expect(results).to contain_exactly(route1, route2)
        end
      end
    end
  end
end
