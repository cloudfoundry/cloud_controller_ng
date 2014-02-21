require "spec_helper"

module VCAP::CloudController
  module Jobs
    describe ExceptionCatchingJob do
      subject(:exception_catching_job) do
        ExceptionCatchingJob.new(handler)
      end

      let(:handler) { double("Handler", perform: "fake-perform") }

      context "#perform" do
        it "delegates to the handler" do
          expect(exception_catching_job.perform).to eq("fake-perform")
        end
      end

      context "#error(job, exception)" do
        let(:job) { double("Job") }
        let(:exception) { double("Exception") }
        before do
          allow(ExceptionMarshaler).to receive("marshal").with(exception).and_return("marshaled exception")
        end

        it "saves the exception on the job as cf_api_error" do
          expect(job).to receive("cf_api_error=").with("marshaled exception")
          expect(job).to receive("save")
          exception_catching_job.error(job, exception)
        end
      end
    end
  end
end