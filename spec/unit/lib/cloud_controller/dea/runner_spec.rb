require 'spec_helper'

module VCAP::CloudController
  module Dea
    describe Runner do
      let(:config) do
        instance_double(Config)
      end

      let(:message_bus) do
        instance_double(CfMessageBus::MessageBus, publish: nil)
      end

      let(:dea_pool) do
        instance_double(Dea::Pool)
      end

      let(:app) do
        instance_double(App, guid: 'fake-app-guid')
      end

      subject(:runner) do
        Runner.new(app, config, message_bus, dea_pool)
      end

      describe '#scale' do
        before do
          allow(Client).to receive(:change_running_instances)
          allow(app).to receive(:previous_changes).and_return(previous_changes)

          runner.scale
        end

        context 'when the app now desires more instances than it used to' do
          let(:previous_changes) { { instances: [10, 15] } }

          it 'increases the number instances' do
            expect(Client).to have_received(:change_running_instances).with(app, 5)
          end
        end

        context 'when the app now desires fewer instances than it used to' do
          let(:previous_changes) do
            { instances: [10, 5] }
          end

          it 'reduces the number instances' do
            expect(Client).to have_received(:change_running_instances).with(app, -5)
          end
        end
      end

      describe '#start' do
        let(:desired_instances) { 0 }

        before do
          allow(app).to receive(:instances).and_return(10)
          allow(Client).to receive(:start)
        end

        context 'when started after staging (so there are existing instances)' do
          it 'only starts the number of additional required' do
            expect(Client).to receive(:start).with(app, instances_to_start: 5)

            staging_result = { started_instances: 5 }
            runner.start(staging_result)
          end
        end

        context 'when starting after the app was stopped' do
          it 'starts the desired number of instances' do
            expect(Client).to receive(:start).with(app, instances_to_start: 10)

            runner.start
          end
        end
      end

      describe '#stop' do
        let(:app_stopper) { instance_double(AppStopper) }

        it 'notifies the DEA to stop the app via NATS' do
          expect(AppStopper).to receive(:new).and_return(app_stopper)
          expect(app_stopper).to receive(:publish_stop).with({ droplet: app.guid })

          runner.stop
        end
      end

      describe '#stop_index' do
        before do
          allow(Client).to receive(:stop_indices)

          runner.stop_index(3)
        end

        it 'stops the given index of the app' do
          expect(Client).to have_received(:stop_indices).with(app, [3])
        end
      end
    end
  end
end
