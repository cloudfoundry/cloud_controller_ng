require 'spec_helper'

module VCAP::CloudController
  RSpec.describe InstancesReporters do
    subject(:instances_reporters) { InstancesReporters.new }

    let(:bbs_instances_client) { instance_double(Diego::BbsInstancesClient) }
    let(:traffic_controller_client) { instance_double(::TrafficController::Client) }

    let(:diego_process) { ProcessModelFactory.make(diego: true) }
    let(:diego_instances_reporter) { instance_double(Diego::InstancesReporter) }

    before do
      CloudController::DependencyLocator.instance.register(:bbs_instances_client, bbs_instances_client)
      CloudController::DependencyLocator.instance.register(:traffic_controller_client, traffic_controller_client)

      allow(Diego::InstancesReporter).to receive(:new).with(bbs_instances_client, traffic_controller_client).and_return(diego_instances_reporter)
    end

    describe '#number_of_starting_and_running_instances_for_process' do
      it 'delegates to the Diego reporter' do
        allow(diego_instances_reporter).to receive(:number_of_starting_and_running_instances_for_process).with(diego_process).and_return(2)

        expect(instances_reporters.number_of_starting_and_running_instances_for_process(diego_process)).to eq(2)
      end

      context 'when the reporter throws an InstancesUnavailable' do
        before do
          allow(diego_instances_reporter).to receive(:number_of_starting_and_running_instances_for_process).and_raise(
            CloudController::Errors::InstancesUnavailable.new('custom error'))
        end

        it 're-raises an as api error and retains the original error message' do
          expect {
            instances_reporters.number_of_starting_and_running_instances_for_process(diego_process)
          }.to raise_error(CloudController::Errors::ApiError, /custom error/)
        end
      end
    end

    describe '#all_instances_for_app' do
      it 'delegates to the Diego reporter' do
        allow(diego_instances_reporter).to receive(:all_instances_for_app).with(diego_process).and_return(4)

        expect(instances_reporters.all_instances_for_app(diego_process)).to eq(4)
      end

      context 'when the reporter throws an InstancesUnavailable' do
        before do
          allow(diego_instances_reporter).to receive(:all_instances_for_app).and_raise(CloudController::Errors::InstancesUnavailable.new('custom error'))
        end

        it 're-raises an as api error and retains the original error message' do
          expect {
            instances_reporters.all_instances_for_app(diego_process)
          }.to raise_error(CloudController::Errors::ApiError, /custom error/)
        end
      end
    end

    describe '#crashed_instances_for_app' do
      it 'delegates to the Diego reporter' do
        allow(diego_instances_reporter).to receive(:crashed_instances_for_app).with(diego_process).and_return(6)

        expect(instances_reporters.crashed_instances_for_app(diego_process)).to eq(6)
      end

      context 'when the reporter throws an InstancesUnavailable' do
        before do
          allow(diego_instances_reporter).to receive(:crashed_instances_for_app).and_raise(CloudController::Errors::InstancesUnavailable.new('custom error'))
        end

        it 're-raises an as api error and retains the original error message' do
          expect {
            instances_reporters.crashed_instances_for_app(diego_process)
          }.to raise_error(CloudController::Errors::ApiError, /custom error/)
        end
      end
    end

    describe '#stats_for_app' do
      it 'delegates to the Diego reporter' do
        allow(diego_instances_reporter).to receive(:stats_for_app).with(diego_process).and_return(2 => {})

        expect(instances_reporters.stats_for_app(diego_process)).to eq(2 => {})
      end

      context 'when the reporter throws an InstancesUnavailable' do
        before do
          allow(diego_instances_reporter).to receive(:stats_for_app).and_raise(CloudController::Errors::InstancesUnavailable.new('custom error'))
        end

        it 're-raises as an ApiError' do
          expect {
            instances_reporters.stats_for_app(diego_process)
          }.to raise_error(CloudController::Errors::ApiError, /Stats server temporarily unavailable/i)
        end
      end
    end

    describe '#number_of_starting_and_running_instances_for_processes' do
      let(:processes) { [diego_process] }

      it 'delegates to the proper reporter' do
        expect(diego_instances_reporter).to receive(:number_of_starting_and_running_instances_for_processes).
          with([diego_process]).and_return({ 2 => {} })
        expect(instances_reporters.number_of_starting_and_running_instances_for_processes(processes)).
          to eq({ 2 => {} })
      end
    end
  end
end
