require "spec_helper"
require "cloud_controller/clock"

module VCAP::CloudController
  describe Clock do
    describe "#start" do
      let(:app_usage_events_cleanup_job) { double(Jobs::Runtime::AppUsageEventsCleanup) }
      let(:app_events_cleanup_job) { double(Jobs::Runtime::AppEventsCleanup) }
      let(:audit_events_cleanup_job) { double(Jobs::Runtime::EventsCleanup) }
      let(:failed_jobs_cleanup_job) { double(Jobs::Runtime::FailedJobsCleanup) }

      let(:app_usage_events_cleanup_enqueuer) { double(Jobs::Enqueuer) }
      let(:app_events_cleanup_enqueuer) { double(Jobs::Enqueuer) }
      let(:audit_events_cleanup_enqueuer) { double(Jobs::Enqueuer) }
      let(:failed_jobs_cleanup_enqueuer) { double(Jobs::Enqueuer) }

      let(:logger) { double(Steno::Logger) }
      let(:config) do
        {
          app_events: { cutoff_age_in_days: 22 },
          app_usage_events: { cutoff_age_in_days: 33 },
          audit_events: { cutoff_age_in_days: 11 },
          failed_jobs: { cutoff_age_in_days: 44 },
        }
      end

      subject(:clock) { Clock.new(config) }

      before do
        allow(logger).to receive(:info)
        allow(Clockwork).to receive(:every).and_yield("dummy.scheduled.job")
        allow(Clockwork).to receive(:run)
        allow(Steno).to receive(:logger).and_return(logger)

        allow(Jobs::Runtime::AppUsageEventsCleanup).to receive(:new).and_return(app_usage_events_cleanup_job)
        allow(Jobs::Enqueuer).to receive(:new).with(app_usage_events_cleanup_job, queue: "cc-generic").and_return(app_usage_events_cleanup_enqueuer)
        allow(app_usage_events_cleanup_enqueuer).to receive(:enqueue)

        allow(Jobs::Runtime::AppEventsCleanup).to receive(:new).and_return(app_events_cleanup_job)
        allow(Jobs::Enqueuer).to receive(:new).with(app_events_cleanup_job, queue: "cc-generic").and_return(app_events_cleanup_enqueuer)
        allow(app_events_cleanup_enqueuer).to receive(:enqueue)

        allow(Jobs::Runtime::EventsCleanup).to receive(:new).and_return(audit_events_cleanup_job)
        allow(Jobs::Enqueuer).to receive(:new).with(audit_events_cleanup_job, queue: "cc-generic").and_return(audit_events_cleanup_enqueuer)
        allow(audit_events_cleanup_enqueuer).to receive(:enqueue)

        allow(Jobs::Runtime::FailedJobsCleanup).to receive(:new).and_return(failed_jobs_cleanup_job)
        allow(Jobs::Enqueuer).to receive(:new).with(failed_jobs_cleanup_job, queue: "cc-generic").and_return(failed_jobs_cleanup_enqueuer)
        allow(failed_jobs_cleanup_enqueuer).to receive(:enqueue)

        clock.start
      end

      it "runs Clockwork" do
        expect(Clockwork).to have_received(:run)
      end

      describe "app_usage_events.cleanup.job" do
        it "schedules an AppUsageEventsCleanup job to run every day during business hours in SF" do
          expect(Clockwork).to have_received(:every).with(1.day, "app_usage_events.cleanup.job", at: "18:00")
          expect(Jobs::Enqueuer).to have_received(:new).with(app_usage_events_cleanup_job, queue: "cc-generic")
          expect(app_usage_events_cleanup_enqueuer).to have_received(:enqueue)
        end

        it "sets the cutoff_age_in_days for AppUsageEventsCleanup to the configured value" do
          expect(Jobs::Runtime::AppUsageEventsCleanup).to have_received(:new).with(33)
        end
      end

      describe "app_events.cleanup.job" do
        it "schedules an AppEventsCleanup job to run every day during business hours in SF" do
          expect(Clockwork).to have_received(:every).with(1.day, "app_events.cleanup.job", at: "19:00")
          expect(Jobs::Enqueuer).to have_received(:new).with(app_events_cleanup_job, queue: "cc-generic")
          expect(app_events_cleanup_enqueuer).to have_received(:enqueue)
        end

        it "sets the cutoff_age_in_days for AppEventsCleanup to the configured value" do
          expect(Jobs::Runtime::AppEventsCleanup).to have_received(:new).with(22)
        end
      end

      describe "audit_events.cleanup.job" do
        it "schedules an EventsCleanup job to run every day during business hours in SF" do
          expect(Clockwork).to have_received(:every).with(1.day, "audit_events.cleanup.job", at: "20:00")
          expect(Jobs::Enqueuer).to have_received(:new).with(audit_events_cleanup_job, queue: "cc-generic")
          expect(audit_events_cleanup_enqueuer).to have_received(:enqueue)
        end

        it "sets the cutoff_age_in_days for EventsCleanup to the configured value" do
          expect(Jobs::Runtime::EventsCleanup).to have_received(:new).with(11)
        end
      end

      describe "failed_jobs.cleanup.job" do
        it "schedules an FailedJobsCleanup job to run every day during business hours in SF" do
          expect(Clockwork).to have_received(:every).with(1.day, "failed_jobs.cleanup.job", at: "21:00")
          expect(Jobs::Enqueuer).to have_received(:new).with(failed_jobs_cleanup_job, queue: "cc-generic")
          expect(failed_jobs_cleanup_enqueuer).to have_received(:enqueue)
        end

        it "sets the cutoff_age_in_days for FailedJobsCleanup to the configured value" do
          expect(Jobs::Runtime::FailedJobsCleanup).to have_received(:new).with(44)
        end
      end

    end
  end
end
