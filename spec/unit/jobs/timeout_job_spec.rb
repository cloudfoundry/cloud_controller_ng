require "spec_helper"

module VCAP::CloudController::Jobs
  describe TimeoutJob do
    let(:job) { double( :job_name_in_configuration => "my-job", max_attempts: 2) }
    let(:timeout_job) { TimeoutJob.new(job) }

    it "runs the provided job" do
      expect(job).to receive(:perform)
      timeout_job.perform
    end

    context "#max_attempts" do
      it "delegates to the handler" do
        expect(timeout_job.max_attempts).to eq(2)
      end
    end

    context "when the job takes longer than its timeout" do
      before do
        allow(job).to receive(:perform) { sleep(2) }
      end

      it "doesn't allow the job to exceed the timeout" do
        expect(timeout_job).to receive(:max_run_time).with("my-job").and_return(1)
        expect{ timeout_job.perform }.to raise_error
      end

      it "raises a VCAP::Errors::JobTimeout to ensure the error message reaches the API consumer" do
        expect(timeout_job).to receive(:max_run_time).with("my-job").and_return(1)
        expect{ timeout_job.perform }.to raise_error(VCAP::Errors::ApiError)
      end
    end

    describe "max_timeout" do
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

      context "by default" do
        it "uses the configured global timeout" do
          expect(timeout_job.max_run_time(:app_bits_packer)).to eq(4.hours)
        end
      end

      context "when an override is specified for this job" do
        let(:overridden_timeout) { 5.minutes }

        before do
          config[:jobs].merge!(app_bits_packer: {
                                 timeout_in_seconds: overridden_timeout
          })
        end

        it "uses the overridden timeout" do
          expect(timeout_job.max_run_time(:app_bits_packer)).to eq(overridden_timeout)
        end
      end
    end
  end
end
