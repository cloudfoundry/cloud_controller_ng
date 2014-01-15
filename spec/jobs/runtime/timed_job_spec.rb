require "spec_helper"

describe VCAP::CloudController::TimedJob do
  describe "#max_run_time" do
    class Tester
      include VCAP::CloudController::TimedJob
    end

    let(:job) { Tester.new }
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
      VCAP::CloudController::Config.stub(:config).and_return(config)
    end

    context "by default" do
      it "uses the configured global timeout" do
        expect(job.max_run_time(:app_bits_packer)).to eq(4.hours)
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
        expect(job.max_run_time(:app_bits_packer)).to eq(overridden_timeout)
      end
    end
  end
end
