require "spec_helper"
require "cloud_controller/clock"

module VCAP::CloudController
  describe Clock do
    describe "#start" do
      let(:app_usage_events_cleanup_job) do
        double(Jobs::Runtime::AppUsageEventsCleanup)
      end

      let(:logger) do
        double(Steno::Logger)
      end

      before do
        allow(logger).to receive(:info)
        allow(Clockwork).to receive(:every).and_yield("dummy.scheduled.job")
        allow(Clockwork).to receive(:run)
        allow(Steno).to receive(:logger).and_return(logger)
        allow(Delayed::Job).to receive(:enqueue)
        allow(Jobs::Runtime::AppUsageEventsCleanup).to receive(:new).with(31).and_return(app_usage_events_cleanup_job)

        Clock.start
      end

      it "schedules a dummy job to run every 10 minutes" do
        expect(Clockwork).to have_received(:every).with(10.minutes, "dummy.scheduled.job")
      end

      it "schedules an AppUsageEventsCleanup job to run every day at" do
        expect(Clockwork).to have_received(:every).with(1.day, "app_usage_events.cleanup.job", at: "18:00")
        expect(Delayed::Job).to have_received(:enqueue).with(app_usage_events_cleanup_job, queue: "cc-generic")
      end

      it "logs a message every time the job runs" do
        expect(Steno).to have_received(:logger).with("cc.clock")
        expect(logger).to have_received(:info).with("Would have run dummy.scheduled.job")
      end

      it "runs Clockwork" do
        expect(Clockwork).to have_received(:run)
      end
    end
  end
end
