require 'spec_helper'
require 'cloud_controller/copilot/adapter'
require 'cloud_controller/copilot/sync'

module VCAP::CloudController
  RSpec.describe Copilot::Sync do
    describe '#sync' do
      let(:istio_domain) { SharedDomain.make(name: 'istio.example.org') }
      let(:internal_istio_domain) { SharedDomain.make(name: 'istio.example.internal', internal: true) }

      before do
        allow(Copilot::Adapter).to receive(:bulk_sync)
        TestConfig.override(copilot: { enabled: true, temporary_istio_domains: [istio_domain.name, internal_istio_domain.name] })
      end

      context 'syncing' do
        let(:app) { VCAP::CloudController::AppModel.make }

        let(:route) { Route.make(domain: istio_domain, host: 'some-host', path: '/some/path') }
        let!(:route_mapping) { RouteMappingModel.make(route: route, app: app, process_type: 'web') }

        let(:internal_route) { Route.make(domain: internal_istio_domain, host: 'internal-host', vip_offset: 1) }
        let!(:internal_route_mapping) { RouteMappingModel.make(route: internal_route, app: app, process_type: 'web') }

        let(:legacy_domain) { SharedDomain.make }
        let(:legacy_route) { Route.make(domain: legacy_domain, host: 'some-host', path: '/some/path') }
        let!(:legacy_route_mapping) { RouteMappingModel.make(route: legacy_route, app: app, process_type: 'web') }

        let(:internal_legacy_domain) { SharedDomain.make(name: 'example.internal', internal: true) }
        let(:internal_legacy_route) { Route.make(domain: internal_legacy_domain, host: 'internal-host') }
        let!(:internal_legacy_route_mapping) { RouteMappingModel.make(route: internal_legacy_route, app: app, process_type: 'web') }

        let!(:web_process_model) { VCAP::CloudController::ProcessModel.make(type: 'web', app: app) }
        let!(:worker_process_model) { VCAP::CloudController::ProcessModel.make(type: 'worker', app: app) }

        before do
          allow(Diego::ProcessGuid).to receive(:from_process).with(web_process_model).and_return('some-diego-process-guid')
        end

        it 'sends istio routes, route_mappings and CDPAs over to the adapter' do
          Copilot::Sync.sync

          expect(Copilot::Adapter).to have_received(:bulk_sync).with(
            {
              routes: [{
                guid: route.guid,
                host: route.fqdn,
                path: route.path,
                internal: false,
                vip: nil
              }, {
                guid: internal_route.guid,
                host: internal_route.fqdn,
                path: '',
                internal: true,
                vip: internal_route.vip
              }],
              route_mappings: [{
                capi_process_guid: web_process_model.guid,
                route_guid: route_mapping.route_guid,
                route_weight: 1
              }, {
                capi_process_guid: web_process_model.guid,
                route_guid: internal_route_mapping.route_guid,
                route_weight: 1
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
                    path: route.path,
                    internal: false,
                    vip: nil
                  }, {
                    guid: internal_route.guid,
                    host: internal_route.fqdn,
                    path: '',
                    internal: true,
                    vip: internal_route.vip
                  }],
                  route_mappings: [{
                    capi_process_guid: web_process_model.guid,
                    route_guid: route_mapping.route_guid,
                    route_weight: 1
                  }, {
                    capi_process_guid: web_process_model.guid,
                    route_guid: internal_route_mapping.route_guid,
                    route_weight: 1
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

      context 'batching' do
        before do
          stub_const('VCAP::CloudController::Copilot::Sync::BATCH_SIZE', 1)
          allow(Diego::ProcessGuid).to receive(:from_process).with(web_process_model_1).and_return('some-diego-process-guid-1')
          allow(Diego::ProcessGuid).to receive(:from_process).with(web_process_model_2).and_return('some-diego-process-guid-2')
        end

        let(:route_1) { Route.make(domain: istio_domain, host: 'some-host', path: '/some/path') }
        let(:route_2) { Route.make(domain: istio_domain, host: 'some-other-host', path: '/some/other/path') }
        let(:app_1) { VCAP::CloudController::AppModel.make }
        let(:app_2) { VCAP::CloudController::AppModel.make }
        let!(:route_mapping_1) { RouteMappingModel.make(route: route_1, app: app_1, process_type: 'web') }
        let!(:route_mapping_2) { RouteMappingModel.make(route: route_2, app: app_2, process_type: 'web') }
        let!(:web_process_model_1) { VCAP::CloudController::ProcessModel.make(type: 'web', app: app_1) }
        let!(:web_process_model_2) { VCAP::CloudController::ProcessModel.make(type: 'web', app: app_2) }

        it 'syncs all of the resources in one go after querying the DB in batches' do
          Copilot::Sync.sync

          expect(Copilot::Adapter).to have_received(:bulk_sync) do |args|
            expect(args[:routes]).to match_array([
              { guid: route_1.guid, host: route_1.fqdn, path: route_1.path, internal: false, vip: nil },
              { guid: route_2.guid, host: route_2.fqdn, path: route_2.path, internal: false, vip: nil }
            ])
            expect(args[:route_mappings]).to match_array([
              {
                capi_process_guid: web_process_model_1.guid,
                route_guid: route_mapping_1.route_guid,
                route_weight: 1
              },
              {
                capi_process_guid: web_process_model_2.guid,
                route_guid: route_mapping_2.route_guid,
                route_weight: 1
              }
            ])
            expect(args[:capi_diego_process_associations]).to match_array([
              {
                capi_process_guid: web_process_model_1.guid,
                diego_process_guids: ['some-diego-process-guid-1']
              },
              {
                capi_process_guid: web_process_model_2.guid,
                diego_process_guids: ['some-diego-process-guid-2']
              }
            ])
          end
        end
      end
    end
  end
end
