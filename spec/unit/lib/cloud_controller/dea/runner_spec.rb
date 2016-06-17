require 'spec_helper'

module VCAP::CloudController
  module Dea
    RSpec.describe Runner do
      let(:config) { TestConfig.config }

      let(:message_bus) do
        instance_double(CfMessageBus::MessageBus, publish: nil)
      end

      let(:dea_pool) do
        instance_double(Dea::Pool)
      end

      let(:blobstore_url_generator) do
        double('blobstore_url_generator', droplet_download_url: 'app_uri')
      end

      let(:num_service_instances) { 1 }

      let(:app) do
        AppFactory.make.tap do |app|
          num_service_instances.times do
            instance = ManagedServiceInstance.make(space: app.space)
            binding = ServiceBinding.make(
              app: app,
              service_instance: instance
            )
            app.add_service_binding(binding)
          end
        end
      end

      let(:app_starter_task) { instance_double(AppStarterTask, start: nil) }

      subject(:runner) do
        Runner.new(app, config, blobstore_url_generator, message_bus, dea_pool)
      end

      before do
        allow(AppStarterTask).to receive(:new).with(app, blobstore_url_generator, config).and_return(app_starter_task)
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
        end

        context 'when started after staging (so there are existing instances)' do
          it 'only starts the number of additional required' do
            expect(app_starter_task).to receive(:start).with(
              hash_including(
                instances_to_start: 5,
              )
            )

            staging_result = { started_instances: 5 }
            runner.start(staging_result)
          end
        end

        context 'when starting after the app was stopped' do
          it 'starts the desired number of instances' do
            expect(app_starter_task).to receive(:start).with(instances_to_start: 10)

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
