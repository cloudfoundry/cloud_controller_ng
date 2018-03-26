require 'spec_helper'
require 'cloud_controller/diego/process_guid'
require 'cloud_controller/backends/copilot_runner_delegator'

module VCAP::CloudController
  RSpec.describe CopilotRunnerDelegator do
    subject(:copilot_delegator) { CopilotRunnerDelegator.new(runner, process) }
    let(:runner) { instance_double(Diego::Runner) }
    let(:process) { instance_double(ProcessModel) }

    before do
      allow(CopilotHandler).to receive(:upsert_capi_diego_process_association)
      allow(CopilotHandler).to receive(:delete_capi_diego_process_association)
    end

    context 'when copilot is enabled' do
      before do
        TestConfig.override(
          {
            copilot: {
              enabled: true
            } }
        )
      end

      it 'delegates start to the runner and then copilot' do
        expect(runner).to receive(:start)
        expect(CopilotHandler).to receive(:upsert_capi_diego_process_association).with process
        copilot_delegator.start
      end

      it 'delegates stop to the runner and then copilot' do
        expect(runner).to receive(:stop)
        expect(CopilotHandler).to receive(:delete_capi_diego_process_association).with process
        copilot_delegator.stop
      end

      it 'delegates other messages to the runner' do
        expect(runner).to receive(:scale)
        copilot_delegator.scale
      end
    end

    context 'when copilot is disabled' do
      before do
        TestConfig.override(
          {
            copilot: {
              enabled: false
            } }
        )
      end

      it 'does not call copilot' do
        allow(runner).to receive(:start)
        allow(runner).to receive(:stop)

        expect(CopilotHandler).not_to receive(:upsert_capi_diego_process_association)
        expect(CopilotHandler).not_to receive(:delete_capi_diego_process_association)
        copilot_delegator.start
        copilot_delegator.stop
      end
    end
  end
end
