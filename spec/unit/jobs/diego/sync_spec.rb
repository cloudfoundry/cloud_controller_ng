require 'spec_helper'

module VCAP::CloudController
  module Jobs::Diego
    RSpec.describe Sync do
      let(:processes_sync) { instance_double(Diego::ProcessesSync) }
      let(:tasks_sync) { instance_double(Diego::ProcessesSync) }
      subject(:job) { Sync.new }

      describe '#perform' do
        let(:config) do
          Config.new({
            diego: {
              temporary_local_sync: true
            },
          })
        end

        before do
          allow(CloudController::DependencyLocator.instance).to receive(:config).and_return(config)
          allow(Diego::ProcessesSync).to receive(:new).with(config: config).and_return(processes_sync)
          allow(Diego::TasksSync).to receive(:new).with(config: config).and_return(tasks_sync)

          allow(processes_sync).to receive(:sync)
          allow(tasks_sync).to receive(:sync)
        end

        it 'syncs processes' do
          job.perform
          expect(processes_sync).to have_received(:sync).once
        end

        it 'syncs tasks' do
          job.perform
          expect(tasks_sync).to have_received(:sync).once
        end

        context 'when local sync are disabled' do
          let(:config) do
            Config.new({
              diego: {
                temporary_local_sync: false
              },
            })
          end

          it 'does not sync processes' do
            job.perform
            expect(processes_sync).not_to have_received(:sync)
          end

          it 'does not sync tasks' do
            job.perform
            expect(tasks_sync).not_to have_received(:sync)
          end
        end

        it 'records sync duration' do
          yielded_block = nil

          allow_any_instance_of(Statsd).to receive(:time) do |_, metric_name, &block|
            expect(metric_name).to eq 'cc.diego_sync.duration'
            yielded_block = block
          end

          job.perform
          expect(processes_sync).to_not have_received(:sync)
          expect(tasks_sync).to_not have_received(:sync)

          yielded_block.call
          expect(processes_sync).to have_received(:sync)
          expect(tasks_sync).to have_received(:sync)
        end
      end
    end
  end
end
