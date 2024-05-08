require 'spec_helper'
require 'actions/route_destination_update'

module VCAP::CloudController
  RSpec.describe RouteDestinationUpdate do
    subject(:destination_update) { RouteDestinationUpdate }

    describe '#update' do
      let(:process) { ProcessModelFactory.make(state: 'STARTED') }
      let!(:destination) { RouteMappingModel.make({ protocol: 'http1', app_guid: process.app.guid, process_type: process.type }) }
      let(:runners) { instance_double(Runners, runner_for_process: runner) }
      let(:runner) { instance_double(Diego::Runner, update_routes: nil) }

      let(:message) do
        VCAP::CloudController::RouteDestinationUpdateMessage.new(
          {
            protocol: 'http2'
          }
        )
      end

      before do
        allow(CloudController::DependencyLocator.instance).to receive(:runners).and_return(runners)
        # allow(VCAP::CloudController::ProcessObserver).to receive(:updated)
      end

      it 'updates the destination record' do
        updated_destination = RouteDestinationUpdate.update(destination, message)

        expect(updated_destination.protocol).to eq 'http2'
      end

      describe 'updating the backend' do
        context 'when the process is started and staged' do
          it 'calls the backend runner', isolation: :truncation do
            RouteDestinationUpdate.update(destination, message)
            expect(runner).to have_received(:update_routes)
          end
        end

        context 'when the process is started but not staged' do
          before do
            process.desired_droplet.destroy
          end

          it 'does not call the backend runner', isolation: :truncation do
            RouteDestinationUpdate.update(destination, message)
            expect(runner).not_to have_received(:update_routes)
          end
        end

        context 'when the process is not started' do
          let(:process) { ProcessModelFactory.make(state: 'STOPPED') }

          it 'does not call the backend runner', isolation: :truncation do
            RouteDestinationUpdate.update(destination, message)
            expect(runner).not_to have_received(:update_routes)
          end
        end

        context 'when an error occurs talking to the backend' do
          it 'does not raise an error' do
            allow(runner).to receive(:update_routes).and_raise(VCAP::CloudController::Diego::Runner::CannotCommunicateWithDiegoError)
            expect { RouteDestinationUpdate.update(destination, message) }.not_to raise_error
          end
        end
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
