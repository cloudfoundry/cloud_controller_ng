require 'spec_helper'
require 'cloud_controller/clock/job_timeout_calculator'

module VCAP::CloudController
  RSpec.describe JobTimeoutCalculator do
    let(:global_timeout) { 1.hour }

    let(:config) do
      Config.new({
                   jobs: {
                     global: { timeout_in_seconds: global_timeout },
                     app_usage_events_cleanup: { timeout_in_seconds: 2.hours },
                     blobstore_delete: { timeout_in_seconds: 3.hours },
                     diego_sync: { timeout_in_seconds: 4.hours },
                   }
                 })
    end

    context 'when a job is specified in the config' do
      it 'returns the job timeout from the config' do
        expect(JobTimeoutCalculator.new(config).calculate(:app_usage_events_cleanup)).to eq(2.hours)
        expect(JobTimeoutCalculator.new(config).calculate(:blobstore_delete)).to eq(3.hours)
        expect(JobTimeoutCalculator.new(config).calculate(:diego_sync)).to eq(4.hours)
      end
    end

    context 'when a job timeout is NOT specified in the config' do
      it 'returns the global timeout' do
        expect(JobTimeoutCalculator.new(config).calculate(:bogus)).to eq(global_timeout)
      end
    end

    context 'when the job_name is nil' do
      it 'returns the global timeout' do
        expect(JobTimeoutCalculator.new(config).calculate(nil)).to eq(global_timeout)
      end
    end
  end
end
