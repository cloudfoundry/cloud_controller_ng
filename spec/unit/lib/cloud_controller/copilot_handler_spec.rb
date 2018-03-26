require 'spec_helper'
require 'cloud_controller/copilot_handler'

module VCAP::CloudController
  RSpec.describe CopilotHandler do
    subject(:handler) { CopilotHandler }
    let(:copilot_client) do
      instance_spy(::Cloudfoundry::Copilot::Client)
    end

    before do
      allow(CloudController::DependencyLocator.instance).to receive(:copilot_client).and_return(copilot_client)
    end

    describe '#create_route' do
      let(:route) { instance_double(Route, guid: 'some-route-guid', fqdn: 'some-fqdn') }

      it 'calls copilot_client.upsert_route' do
        handler.create_route(route)
        expect(copilot_client).to have_received(:upsert_route).with(
          guid: 'some-route-guid',
          host: 'some-fqdn'
        )
      end

      context 'when copilot_client.upsert_route returns an error' do
        before do
          allow(copilot_client).to receive(:upsert_route).and_raise('uh oh')
        end

        it 'raises a CopilotUnavailable exception' do
          expect { handler.create_route(route) }.to raise_error(CopilotHandler::CopilotUnavailable, 'uh oh')
        end
      end
    end

    describe '#map_route' do
      let(:capi_process_guid) { 'some-capi-process-guid' }
      let(:diego_process_guid) { 'some-diego-process-guid' }
      let(:route_guid) { 'some-route-guid' }
      let(:route) { instance_double(Route, guid: route_guid) }
      let(:process) { instance_double(ProcessModel, guid: capi_process_guid) }
      let(:route_mapping) do
        instance_double(
          RouteMappingModel,
          process: process,
          route: route,
        )
      end

      before do
        allow(Diego::ProcessGuid).to receive(:from_process).with(process).and_return(diego_process_guid)
      end

      it 'calls copilot_client.map_route' do
        handler.map_route(route_mapping)
        expect(copilot_client).to have_received(:map_route).with(
          capi_process_guid: capi_process_guid,
          route_guid: route_guid
        )
      end

      context 'when copilot_client.map_route returns an error' do
        before do
          allow(copilot_client).to receive(:map_route).and_raise('uh oh')
        end

        it 'raises a CopilotUnavailable exception' do
          expect { handler.map_route(route_mapping) }.to raise_error(CopilotHandler::CopilotUnavailable, 'uh oh')
        end
      end
    end

    describe '#unmap_route' do
      let(:capi_process_guid) { 'some-capi-process-guid' }
      let(:route_guid) { 'some-route-guid' }
      let(:route) { instance_double(Route, guid: route_guid) }
      let(:process) { instance_double(ProcessModel, guid: capi_process_guid) }
      let(:route_mapping) do
        instance_double(
          RouteMappingModel,
          process: process,
          route: route,
        )
      end

      it 'calls copilot_client.map_route' do
        handler.unmap_route(route_mapping)
        expect(copilot_client).to have_received(:unmap_route).with(
          capi_process_guid: capi_process_guid,
          route_guid: route_guid
        )
      end

      context 'when copilot_client.unmap_route returns an error' do
        before do
          allow(copilot_client).to receive(:unmap_route).and_raise('uh oh')
        end

        it 'raises a CopilotUnavailable exception' do
          expect { handler.unmap_route(route_mapping) }.to raise_error(CopilotHandler::CopilotUnavailable, 'uh oh')
        end
      end
    end

    describe '#upsert_capi_diego_process_association' do
      let(:capi_process_guid) { 'some-capi-process-guid' }
      let(:diego_process_guid) { 'some-diego-process-guid' }
      let(:process) { instance_double(ProcessModel, guid: capi_process_guid) }

      before do
        allow(Diego::ProcessGuid).to receive(:from_process).with(process).and_return(diego_process_guid)
      end

      it 'calls copilot_client.upsert_capi_diego_process_association' do
        handler.upsert_capi_diego_process_association(process)
        expect(copilot_client).to have_received(:upsert_capi_diego_process_association).with(
          capi_process_guid: capi_process_guid,
          diego_process_guids: [diego_process_guid]
        )
      end

      context 'when copilot_client.upsert_capi_diego_process_association returns an error' do
        before do
          allow(copilot_client).to receive(:upsert_capi_diego_process_association).and_raise('uh oh')
        end

        it 'raises a CopilotUnavailable exception' do
          expect { handler.upsert_capi_diego_process_association(process) }.to raise_error(CopilotHandler::CopilotUnavailable, 'uh oh')
        end
      end
    end

    describe '#delete_capi_diego_process_association' do
      let(:capi_process_guid) { 'some-capi-process-guid' }
      let(:process) { instance_double(ProcessModel, guid: capi_process_guid) }

      it 'calls copilot_client.delete_capi_diego_process_association' do
        handler.delete_capi_diego_process_association(process)
        expect(copilot_client).to have_received(:delete_capi_diego_process_association).with(
          capi_process_guid: capi_process_guid
        )
      end

      context 'when copilot_client.delete_capi_diego_process_association returns an error' do
        before do
          allow(copilot_client).to receive(:delete_capi_diego_process_association).and_raise('uh oh')
        end

        it 'raises a CopilotUnavailable exception' do
          expect { handler.delete_capi_diego_process_association(process) }.to raise_error(CopilotHandler::CopilotUnavailable, 'uh oh')
        end
      end
    end
  end
end
