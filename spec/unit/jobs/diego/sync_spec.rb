require 'spec_helper'

module VCAP::CloudController
  module Jobs::Diego
    RSpec.describe Sync, job_context: :clock do
      let(:processes_sync) { instance_double(Diego::ProcessesSync) }
      let(:tasks_sync) { instance_double(Diego::ProcessesSync) }
      subject(:job) { Sync.new }

      describe '#perform' do
        before do
          allow(Diego::ProcessesSync).to receive(:new).and_return(processes_sync)
          allow(Diego::TasksSync).to receive(:new).and_return(tasks_sync)

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

        it 'records sync duration' do
          allow(Time).to receive(:now).and_call_original
          allow_any_instance_of(VCAP::CloudController::Diego::ProcessesSync).to receive(:sync)
          allow_any_instance_of(VCAP::CloudController::Diego::TasksSync).to receive(:sync)

          expect(processes_sync).to receive(:sync)
          expect(tasks_sync).to receive(:sync)
          expect(Time).to receive(:now).twice # Ensure that we get two time measurements. _Hopefully_ they get turned into an elapsed time and passed in where they need to be!
          expect_any_instance_of(Statsd).to receive(:timing).with('cc.diego_sync.duration', kind_of(Numeric))
          expect_any_instance_of(VCAP::CloudController::Metrics::PrometheusUpdater).to receive(:report_diego_cell_sync_duration).with(kind_of(Numeric))

          job.perform
        end
      end
    end
  end
end
