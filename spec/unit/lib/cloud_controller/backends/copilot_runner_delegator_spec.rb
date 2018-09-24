require 'spec_helper'
require 'cloud_controller/diego/process_guid'
require 'cloud_controller/backends/copilot_runner_delegator'

module VCAP::CloudController
  RSpec.describe CopilotRunnerDelegator do
    subject(:copilot_delegator) { CopilotRunnerDelegator.new(runner, process) }
    let(:runner) { instance_double(Diego::Runner) }
    let(:process) { instance_double(ProcessModel) }

    before do
      allow(Copilot::Adapter).to receive(:upsert_capi_diego_process_association)
      allow(Copilot::Adapter).to receive(:delete_capi_diego_process_association)
    end

    it 'delegates start to the runner and then copilot' do
      expect(runner).to receive(:start)
      expect(Copilot::Adapter).to receive(:upsert_capi_diego_process_association).with process
      copilot_delegator.start
    end

    it 'delegates stop to the runner and then copilot' do
      expect(runner).to receive(:stop)
      expect(Copilot::Adapter).to receive(:delete_capi_diego_process_association).with process
      copilot_delegator.stop
    end

    it 'delegates other messages to the runner' do
      expect(runner).to receive(:scale)
      copilot_delegator.scale
    end
  end
end
