require 'spec_helper'
require 'actions/route_destination_update'

module VCAP::CloudController
  RSpec.describe RouteDestinationUpdate do
    subject(:destination_update) { RouteDestinationUpdate }

    describe '#update' do
      let(:process) { ProcessModelFactory.make(state: 'STARTED') }
      let!(:destination) { RouteMappingModel.make({ protocol: 'http1', app_guid: process.app.guid, process_type: process.type }) }
      let(:process_route_handler) { instance_double(ProcessRouteHandler, notify_backend_of_route_update: nil) }

      let(:message) do
        VCAP::CloudController::RouteDestinationUpdateMessage.new(
          {
            protocol: 'http2'
          }
        )
      end

      before do
        allow(ProcessRouteHandler).to receive(:new).with(process).and_return(process_route_handler)
      end

      it 'updates the destination record' do
        updated_destination = RouteDestinationUpdate.update(destination, message)

        expect(updated_destination.protocol).to eq 'http2'
      end

      it 'notifies the backend of route updates' do
        RouteDestinationUpdate.update(destination, message)
        expect(process_route_handler).to have_received(:notify_backend_of_route_update)
      end

      context 'when the given protocol is incompatible' do
        context 'for tcp route' do
          let(:routing_api_client) { double('routing_api_client', router_group:) }
          let(:router_group) { double('router_group', type: 'tcp', guid: 'router-group-guid') }
          let(:tcp_route) do
            UAARequests.stub_all
            allow_any_instance_of(CloudController::DependencyLocator).to receive(:routing_api_client).and_return(routing_api_client)
            allow_any_instance_of(VCAP::CloudController::RouteValidator).to receive(:validate)

            VCAP::CloudController::Route.make(:tcp)
          end
          let!(:tcp_destination) { RouteMappingModel.make({ route: tcp_route }) }

          it 'does not update the destination record' do
            expect { RouteDestinationUpdate.update(tcp_destination, message) }.to raise_error(StandardError)
          end
        end

        context 'for http route' do
          it 'does not update the destination record' do
            message.protocol = 'tcp'
            expect(message).to be_valid
            expect { RouteDestinationUpdate.update(destination, message) }.to raise_error(StandardError)
          end
        end
      end
    end
  end
end
