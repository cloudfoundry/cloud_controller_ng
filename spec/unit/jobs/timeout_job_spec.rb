require 'spec_helper'

module VCAP::CloudController::Jobs
  RSpec.describe TimeoutJob do
    let(:job) { double(job_name_in_configuration: 'my-job', max_attempts: 2) }
    let(:timeout) { 0.01.second }
    let(:timeout_job) { TimeoutJob.new(job, timeout) }

    it 'runs the provided job' do
      expect(job).to receive(:perform)
      timeout_job.perform
    end

    context '#max_attempts' do
      it 'delegates to the handler' do
        expect(timeout_job.max_attempts).to eq(2)
      end
    end

    context 'when the job takes longer than its timeout' do
      before do
        allow(job).to receive(:perform) { sleep(2) }
      end

      it 'raises an error after the timeout has elapsed' do
        expect { timeout_job.perform }.to raise_error CloudController::Errors::ApiError, /job.+timed out/
      end

      context 'and the job specifies a custom timeout error' do
        let(:custom_timeout_error) { StandardError.new('Yo, a timeout occurred') }
        let(:job) do
          double(
            job_name_in_configuration: 'my-job-with-custom-timeout',
            max_attempts: 2,
            timeout_error: custom_timeout_error
          )
        end

        it 'raises the timeout error the job wants' do
          expect { timeout_job.perform }.to raise_error(custom_timeout_error)
        end
      end
    end

    describe '#reschedule_at' do
      before do
        allow(job).to receive(:reschedule_at) do |time, attempts|
          time + attempts
        end
      end

      it 'defers to the inner job' do
        time = Time.now
        attempts = 5
        expect(timeout_job.reschedule_at(time, attempts)).to eq(job.reschedule_at(time, attempts))
      end
    end
  end
end
