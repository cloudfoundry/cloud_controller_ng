require 'spec_helper'
require 'cloud_controller/copilot/adapter'
require 'cloud_controller/copilot/sync'

module VCAP::CloudController
  RSpec.describe Copilot::Sync do
    describe '#sync' do
      let(:domain) { SharedDomain.make(name: 'example.org') }
      let(:route) { Route.make(domain: domain, host: 'some-host', path: '/some/path') }

      let(:app) { VCAP::CloudController::AppModel.make }
      let!(:route_mapping) { RouteMappingModel.make(route: route, app: app, process_type: 'web') }
      let!(:web_process_model) { VCAP::CloudController::ProcessModel.make(type: 'web', app: app) }
      let!(:worker_process_model) { VCAP::CloudController::ProcessModel.make(type: 'worker', app: app) }

      before do
        allow(Copilot::Adapter).to receive(:bulk_sync)
        allow(Diego::ProcessGuid).to receive(:from_process).with(web_process_model).and_return('some-diego-process-guid')
      end

      it 'syncs routes, route_mappings, and web processes' do
        Copilot::Sync.sync

        expect(Copilot::Adapter).to have_received(:bulk_sync).with(
          {
            routes: [{
              guid: route.guid,
              host: route.fqdn,
              path: route.path
            }],
            route_mappings: [{
              capi_process_guid: web_process_model.guid,
              route_guid: route_mapping.route_guid,
              route_weight: route_mapping.weight
            }],
            capi_diego_process_associations: [{
              capi_process_guid: web_process_model.guid,
              diego_process_guids: ['some-diego-process-guid']
            }]
          }
        )
      end

      context 'race conditions' do
        context "when a route mapping's process has been deleted" do
          let!(:bad_route_mapping) { RouteMappingModel.make(process: nil, route: route) }

          it 'does not sync that route mapping' do
            Copilot::Sync.sync

            expect(Copilot::Adapter).to have_received(:bulk_sync).with(
              {
                routes: [{
                  guid: route.guid,
                  host: route.fqdn,
                  path: route.path
                }],
                route_mappings: [{
                  capi_process_guid: web_process_model.guid,
                  route_guid: route_mapping.route_guid,
                  route_weight: route_mapping.weight
                }],
                capi_diego_process_associations: [{
                  capi_process_guid: web_process_model.guid,
                  diego_process_guids: ['some-diego-process-guid']
                }]
              }
            )
          end
        end
      end
    end
  end
end
