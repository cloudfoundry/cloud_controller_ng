require 'spec_helper'

module VCAP::CloudController
  module Jobs::Diego
    RSpec.describe Sync do
      let(:processes_sync) { instance_double(Diego::ProcessesSync) }
      let(:tasks_sync) { instance_double(Diego::ProcessesSync) }
      subject(:job) { Sync.new }

      describe '#perform' do
        let(:config) do
          {
            diego: {
              temporary_local_apps: true,
              temporary_local_tasks: true,
            },
          }
        end

        before do
          allow(CloudController::DependencyLocator.instance).to receive(:config).and_return(config)
          allow(Diego::ProcessesSync).to receive(:new).with(config).and_return(processes_sync)
          allow(Diego::TasksSync).to receive(:new).with(config).and_return(tasks_sync)

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

        it 'runs at most once in parallel' do
          allow(tasks_sync).to receive(:sync) { sleep 1 }

          threads = [
            Thread.new { job.perform },
            Thread.new { job.perform },
          ]
          threads.each { |t| t.join(0.5) }
          threads.each(&:kill)

          expect(processes_sync).to have_received(:sync).once
          expect(tasks_sync).to have_received(:sync).once
        end

        context 'when local apps are disabled' do
          let(:config) do
            {
              diego: {
                temporary_local_apps: false,
                temporary_local_tasks: true,
              },
            }
          end

          it 'does not sync processes' do
            job.perform
            expect(processes_sync).not_to have_received(:sync)
          end
        end

        context 'when local tasks are disabled' do
          let(:config) do
            {
              diego: {
                temporary_local_apps: true,
                temporary_local_tasks: false,
              },
            }
          end

          it 'does not sync tasks' do
            job.perform
            expect(tasks_sync).not_to have_received(:sync)
          end
        end
      end
    end
  end
end
