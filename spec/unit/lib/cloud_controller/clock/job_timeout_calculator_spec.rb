require 'spec_helper'
require 'cloud_controller/clock/job_timeout_calculator'

module VCAP::CloudController
  RSpec.describe JobTimeoutCalculator do
    let(:config) do
      {
        jobs: {
          global: {
            timeout_in_seconds: global_timeout
          }
        }
      }
    end
    let(:global_timeout) { 4.hours }
    let(:my_job_timeout) { 2.hours }
    let(:job_name) { 'my_job' }

    context 'when a job is specified in the config' do
      let(:config) do
        {
          jobs: {
            my_job: {
              timeout_in_seconds: my_job_timeout
            }
          }
        }
      end

      it 'returns the job timeout from the config' do
        expect(JobTimeoutCalculator.new(config).calculate(job_name)).to eq(my_job_timeout)
      end
    end

    context 'when a job timeout is NOT specified in the config' do
      let(:config) do
        {
          jobs: {
            global: {
              timeout_in_seconds: global_timeout
            }
          }
        }
      end

      it 'returns the global timeout' do
        expect(JobTimeoutCalculator.new(config).calculate(job_name)).to eq(global_timeout)
      end
    end

    context 'when the job_name is nil' do
      let(:job_name) { nil }

      it 'returns the global timeout' do
        expect(JobTimeoutCalculator.new(config).calculate(job_name)).to eq(global_timeout)
      end
    end
  end
end
