require "spec_helper"
require "cloud_controller/clock"

module VCAP::CloudController
  describe Clock do
    describe "#start" do
      let(:app_usage_events_cleanup_job) { double(Jobs::Runtime::AppUsageEventsCleanup) }
      let(:app_events_cleanup_job) { double(Jobs::Runtime::AppEventsCleanup) }
      let(:audit_events_cleanup_job) { double(Jobs::Runtime::EventsCleanup) }
      let(:logger) { double(Steno::Logger) }
      let(:config) do
        {
          app_events: { cutoff_age_in_days: 22 },
          app_usage_events: { cutoff_age_in_days: 33 },
          audit_events: { cutoff_age_in_days: 11 },
        }
      end

      subject(:clock) { Clock.new(config) }

      before do
        allow(logger).to receive(:info)
        allow(Clockwork).to receive(:every).and_yield("dummy.scheduled.job")
        allow(Clockwork).to receive(:run)
        allow(Steno).to receive(:logger).and_return(logger)
        allow(Delayed::Job).to receive(:enqueue)
        allow(Jobs::Runtime::AppUsageEventsCleanup).to receive(:new).and_return(app_usage_events_cleanup_job)
        allow(Jobs::Runtime::AppEventsCleanup).to receive(:new).and_return(app_events_cleanup_job)
        allow(Jobs::Runtime::EventsCleanup).to receive(:new).and_return(audit_events_cleanup_job)

        clock.start
      end

      it "runs Clockwork" do
        expect(Clockwork).to have_received(:run)
      end

      describe "app_usage_events.cleanup.job" do
        it "schedules an AppUsageEventsCleanup job to run every day during business hours in SF" do
          expect(Clockwork).to have_received(:every).with(1.day, "app_usage_events.cleanup.job", at: "18:00")
          expect(Delayed::Job).to have_received(:enqueue).with(app_usage_events_cleanup_job, queue: "cc-generic")
        end

        it "sets the cutoff_age_in_days for AppUsageEventsCleanup to the configured value" do
          expect(Jobs::Runtime::AppUsageEventsCleanup).to have_received(:new).with(33)
        end
      end

      describe "app_events.cleanup.job" do
        it "schedules an AppEventsCleanup job to run every day during business hours in SF" do
          expect(Clockwork).to have_received(:every).with(1.day, "app_events.cleanup.job", at: "19:00")
          expect(Delayed::Job).to have_received(:enqueue).with(app_events_cleanup_job, queue: "cc-generic")
        end

        it "sets the cutoff_age_in_days for AppEventsCleanup to the configured value" do
          expect(Jobs::Runtime::AppEventsCleanup).to have_received(:new).with(22)
        end
      end

      describe "audit_events.cleanup.job" do
        it "schedules an EventsCleanup job to run every day during business hours in SF" do
          expect(Clockwork).to have_received(:every).with(1.day, "audit_events.cleanup.job", at: "20:00")
          expect(Delayed::Job).to have_received(:enqueue).with(audit_events_cleanup_job, queue: "cc-generic")
        end

        it "sets the cutoff_age_in_days for EventsCleanup to the configured value" do
          expect(Jobs::Runtime::EventsCleanup).to have_received(:new).with(11)
        end
      end
    end
  end
end
