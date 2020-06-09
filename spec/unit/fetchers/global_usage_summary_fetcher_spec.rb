require 'spec_helper'

module VCAP::CloudController
  RSpec.describe GlobalUsageSummaryFetcher do
    subject(:fetcher) { GlobalUsageSummaryFetcher }

    describe '.summary' do
      let!(:task) { TaskModel.make(state: TaskModel::RUNNING_STATE, memory_in_mb: 100) }
      let!(:completed_task) { TaskModel.make(state: TaskModel::SUCCEEDED_STATE, memory_in_mb: 100) }
      let!(:started_process1) { ProcessModelFactory.make(instances: 3, state: 'STARTED', memory: 100) }
      let!(:started_process2) { ProcessModelFactory.make(instances: 6, state: 'STARTED', memory: 100) }
      let!(:started_process3) { ProcessModelFactory.make(instances: 7, state: 'STARTED', memory: 100) }
      let!(:stopped_process) { ProcessModelFactory.make(instances: 2, state: 'STOPPED', memory: 100) }
      let!(:process2) { ProcessModelFactory.make(instances: 5, state: 'STARTED', memory: 100) }

      it 'returns a summary' do
        summary = fetcher.summary

        expect(summary.started_instances).to eq(21)
        expect(summary.memory_in_mb).to eq(2200)
      end
    end
  end
end
