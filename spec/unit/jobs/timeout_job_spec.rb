require 'spec_helper'

module VCAP::CloudController::Jobs
  describe TimeoutJob do
    let(:job) { double(job_name_in_configuration: 'my-job', max_attempts: 2) }
    let(:timeout_job) { TimeoutJob.new(job) }

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

      it "doesn't allow the job to exceed the timeout" do
        expect(timeout_job).to receive(:max_run_time).with('my-job').and_return(1)
        expect { timeout_job.perform }.to raise_error
      end

      context 'and the job does not specify a custom timeout error' do
        it 'raises a VCAP::Errors::JobTimeout to ensure the error message reaches the API consumer' do
          expect(timeout_job).to receive(:max_run_time).with('my-job').and_return(1)
          expect { timeout_job.perform }.to raise_error(VCAP::Errors::ApiError)
        end
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
          expect(timeout_job).to receive(:max_run_time).with('my-job-with-custom-timeout').and_return(1)
          expect { timeout_job.perform }.to raise_error(custom_timeout_error)
        end
      end
    end

    context 'when the job does not have a configuration name' do
      let(:job) { double(max_attempts: 2) }

      before do
        allow(job).to receive(:perform).and_return(true)
      end

      it 'runs the job with the default timeout' do
        expect { timeout_job.perform }.not_to raise_error
      end
    end

    describe 'max_timeout' do
      let(:config) do
        {
          jobs: {
            global: {
              timeout_in_seconds: 4.hours
            }
          }
        }
      end

      before do
        allow(VCAP::CloudController::Config).to receive(:config).and_return(config)
      end

      context 'by default' do
        it 'uses the configured global timeout' do
          expect(timeout_job.max_run_time(:app_bits_packer)).to eq(4.hours)
        end
      end

      context 'when an override is specified for this job' do
        let(:overridden_timeout) { 5.minutes }

        before do
          config[:jobs].merge!(app_bits_packer: {
                                 timeout_in_seconds: overridden_timeout
          })
        end

        it 'uses the overridden timeout' do
          expect(timeout_job.max_run_time(:app_bits_packer)).to eq(overridden_timeout)
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
