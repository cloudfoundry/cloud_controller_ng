require "spec_helper"

module VCAP::CloudController::Jobs
  describe Enqueuer do
    describe "#enqueue" do
      let(:job) { Runtime::DropletDeletion.new("one", "two") }
      let(:timeout_job) { TimeoutJob.new(job) }
      let(:exception_catching_job) { ExceptionCatchingJob.new(timeout_job) }
      let(:opts) { {:queue => "my-queue"} }

      it "delegates to Delayed::Job" do
        expect(Delayed::Job).to receive(:enqueue).with(exception_catching_job, opts)
        Enqueuer.new(job, opts).enqueue
      end
    end
  end
end