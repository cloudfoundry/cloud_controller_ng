require "spec_helper"

module VCAP::CloudController::Jobs
  describe Enqueuer do
    describe "#enqueue" do
      let(:job) { Runtime::DropletDeletion.new("one", "two") }
      let(:opts) { {:queue => "my-queue"} }

      it "delegates to Delayed::Job" do
        expect(Delayed::Job).to receive(:enqueue).with(TimeoutJob.new(job), opts)
        Enqueuer.new(job, opts).enqueue()
      end
    end
  end
end