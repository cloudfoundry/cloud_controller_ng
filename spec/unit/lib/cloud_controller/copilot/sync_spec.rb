require 'spec_helper'
require 'cloud_controller/copilot/adapter'
require 'cloud_controller/copilot/sync'

module VCAP::CloudController
  RSpec.describe Copilot::Sync do
    describe '#sync' do
      let(:route) { Route.make(domain: domain, host: 'some-host') }
      let(:domain) { SharedDomain.make(name: 'example.org') }
      let!(:route_mapping) { RouteMappingModel.make(route: route) }
      let!(:web_process_model) { VCAP::CloudController::ProcessModel.make(type: 'web') }
      let!(:worker_process_model) { VCAP::CloudController::ProcessModel.make(type: 'worker') }

      before do
        allow(Copilot::Adapter).to receive(:bulk_sync)
      end

      it 'syncs routes, route_mappings, and web processes' do
        Copilot::Sync.sync

        expect(Copilot::Adapter).to have_received(:bulk_sync) do |args|
          expect(args[:routes].first.guid).to eq(route.guid)
          expect(args[:routes].first.fqdn).to eq('some-host.example.org')
          expect(args[:route_mappings]).to eq([route_mapping])
          expect(args[:processes]).to eq([web_process_model])
        end
      end
    end
  end
end
