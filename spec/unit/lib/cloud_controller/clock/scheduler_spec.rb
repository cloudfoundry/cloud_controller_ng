require 'spec_helper'
require 'cloud_controller/clock/scheduler'

module VCAP::CloudController
  RSpec.describe Scheduler, job_context: :clock do
    describe '#start' do
      subject(:schedule) { Scheduler.new(TestConfig.config_instance) }

      let(:clock) { instance_double(Clock) }
      let(:global_timeout) { 4.hours }

      before do
        allow(Clock).to receive(:new).with(no_args).and_return(clock)
        allow(Clockwork).to receive(:run)
        TestConfig.override(
          jobs: {
            global: { timeout_in_seconds: global_timeout }
          },
          app_usage_events: {
            cutoff_age_in_days: 1,
            threshold_for_keeping_unprocessed_records: 5_000_000
          },
          audit_events: { cutoff_age_in_days: 3 },
          failed_jobs: { frequency_in_seconds: 400, cutoff_age_in_days: 4, max_number_of_failed_delayed_jobs: 10 },
          pollable_jobs: { cutoff_age_in_days: 2 },
          service_operations_initial_cleanup: { frequency_in_seconds: 600 },
          service_usage_events: {
            cutoff_age_in_days: 5,
            threshold_for_keeping_unprocessed_records: 5_000_000
          },
          completed_tasks: { cutoff_age_in_days: 6 },
          pending_droplets: { frequency_in_seconds: 300, expiration_in_seconds: 600 },
          pending_builds: { frequency_in_seconds: 400, expiration_in_seconds: 700 },
          diego_sync: { frequency_in_seconds: 30 },
          max_retained_deployments_per_app: 15,
          max_retained_builds_per_app: 15,
          max_retained_revisions_per_app: 15
        )
      end

      it 'configures Clockwork with a logger' do
        allow(clock).to receive(:schedule_frequent_worker_job)
        allow(clock).to receive(:schedule_frequent_inline_job)
        allow(clock).to receive(:schedule_daily_job)

        error = StandardError.new 'Boom!'
        allow(Clockwork).to receive(:error_handler).and_yield(error)
        expect_any_instance_of(Steno::Logger).to receive(:error).with("#{error} (#{error.class.name})")
        expect do
          schedule.start
        end.to raise_error(StandardError, 'Boom!')
      end

      it 'runs Clockwork' do
        allow(clock).to receive(:schedule_frequent_worker_job)
        allow(clock).to receive(:schedule_frequent_inline_job)
        allow(clock).to receive(:schedule_daily_job)

        schedule.start

        expect(Clockwork).to have_received(:run)
      end

      it 'schedules cleanup for all daily jobs' do
        allow(clock).to receive(:schedule_frequent_worker_job)
        allow(clock).to receive(:schedule_frequent_inline_job)

        expect(clock).to receive(:schedule_daily_job) do |args, &block|
          expect(args).to eql(name: 'app_usage_events', at: '18:00', priority: 0)
          expect(Jobs::Runtime::AppUsageEventsCleanup).to receive(:new).with(1, 5_000_000).and_call_original
          expect(block.call).to be_instance_of(Jobs::Runtime::AppUsageEventsCleanup)
        end

        expect(clock).to receive(:schedule_daily_job) do |args, &block|
          expect(args).to eql(name: 'audit_events', at: '20:00', priority: 0)
          expect(Jobs::Runtime::EventsCleanup).to receive(:new).with(3).and_call_original
          expect(block.call).to be_instance_of(Jobs::Runtime::EventsCleanup)
        end

        expect(clock).to receive(:schedule_daily_job) do |args, &block|
          expect(args).to eql(name: 'service_usage_events', at: '22:00', priority: 0)
          expect(Jobs::Services::ServiceUsageEventsCleanup).to receive(:new).with(5, 5_000_000).and_call_original
          expect(block.call).to be_instance_of(Jobs::Services::ServiceUsageEventsCleanup)
        end

        expect(clock).to receive(:schedule_daily_job) do |args, &block|
          expect(args).to eql(name: 'completed_tasks', at: '23:00', priority: 0)
          expect(Jobs::Runtime::PruneCompletedTasks).to receive(:new).with(6).and_call_original
          expect(block.call).to be_instance_of(Jobs::Runtime::PruneCompletedTasks)
        end

        expect(clock).to receive(:schedule_daily_job) do |args, &block|
          expect(args).to eql(name: 'expired_blob_cleanup', at: '00:00', priority: 0)
          expect(Jobs::Runtime::ExpiredBlobCleanup).to receive(:new).with(no_args).and_call_original
          expect(block.call).to be_instance_of(Jobs::Runtime::ExpiredBlobCleanup)
        end

        expect(clock).to receive(:schedule_daily_job) do |args, &block|
          expect(args).to eql(name: 'expired_resource_cleanup', at: '00:30', priority: 0)
          expect(Jobs::Runtime::ExpiredResourceCleanup).to receive(:new).with(no_args).and_call_original
          expect(block.call).to be_instance_of(Jobs::Runtime::ExpiredResourceCleanup)
        end

        expect(clock).to receive(:schedule_daily_job) do |args, &block|
          expect(args).to eql(name: 'expired_orphaned_blob_cleanup', at: '01:00', priority: 0)
          expect(Jobs::Runtime::ExpiredOrphanedBlobCleanup).to receive(:new).with(no_args).and_call_original
          expect(block.call).to be_instance_of(Jobs::Runtime::ExpiredOrphanedBlobCleanup)
        end

        expect(clock).to receive(:schedule_daily_job) do |args, &block|
          expect(args).to eql(name: 'orphaned_blobs_cleanup', at: '01:30', priority: 1)
          expect(Jobs::Runtime::OrphanedBlobsCleanup).to receive(:new).with(no_args).and_call_original
          expect(block.call).to be_instance_of(Jobs::Runtime::OrphanedBlobsCleanup)
        end

        expect(clock).to receive(:schedule_daily_job) do |args, &block|
          expect(args).to eql(name: 'pollable_job_cleanup', at: '02:00', priority: 0)
          expect(Jobs::Runtime::PollableJobCleanup).to receive(:new).with(2).and_call_original
          expect(block.call).to be_instance_of(Jobs::Runtime::PollableJobCleanup)
        end

        expect(clock).to receive(:schedule_daily_job) do |args, &block|
          expect(args).to eql(name: 'prune_completed_deployments', at: '03:00', priority: 0)
          expect(Jobs::Runtime::PruneCompletedDeployments).to receive(:new).with(15).and_call_original
          expect(block.call).to be_instance_of(Jobs::Runtime::PruneCompletedDeployments)
        end

        expect(clock).to receive(:schedule_daily_job) do |args, &block|
          expect(args).to eql(name: 'prune_completed_builds', at: '03:30', priority: 0)
          expect(Jobs::Runtime::PruneCompletedBuilds).to receive(:new).with(15).and_call_original
          expect(block.call).to be_instance_of(Jobs::Runtime::PruneCompletedBuilds)
        end

        expect(clock).to receive(:schedule_daily_job) do |args, &block|
          expect(args).to eql(name: 'prune_excess_app_revisions', at: '03:35', priority: 0)
          expect(Jobs::Runtime::PruneExcessAppRevisions).to receive(:new).with(15).and_call_original
          expect(block.call).to be_instance_of(Jobs::Runtime::PruneExcessAppRevisions)
        end

        schedule.start
      end

      it 'schedules the frequent worker jobs' do
        allow(clock).to receive(:schedule_daily_job)
        allow(clock).to receive(:schedule_frequent_inline_job)
        expect(clock).to receive(:schedule_frequent_worker_job) do |args, &block|
          expect(args).to eql(name: 'pending_droplets', interval: 300)
          expect(Jobs::Runtime::PendingDropletCleanup).to receive(:new).with(expiration_in_seconds: 600).and_call_original
          expect(block.call).to be_instance_of(Jobs::Runtime::PendingDropletCleanup)
        end

        expect(clock).to receive(:schedule_frequent_worker_job) do |args, &block|
          expect(args).to eql(name: 'pending_builds', interval: 400)
          expect(Jobs::Runtime::PendingBuildCleanup).to receive(:new).with(expiration_in_seconds: 700).and_call_original
          expect(block.call).to be_instance_of(Jobs::Runtime::PendingBuildCleanup)
        end

        expect(clock).to receive(:schedule_frequent_worker_job) do |args, &block|
          expect(args).to eql(name: 'failed_jobs', interval: 400)
          expect(Jobs::Runtime::FailedJobsCleanup).to receive(:new).with(cutoff_age_in_days: 4, max_number_of_failed_delayed_jobs: 10).and_call_original
          expect(block.call).to be_instance_of(Jobs::Runtime::FailedJobsCleanup)
        end

        expect(clock).to receive(:schedule_frequent_worker_job) do |args, &block|
          expect(args).to eql(name: 'service_operations_initial_cleanup', interval: 600)
          expect(Jobs::Runtime::ServiceOperationsInitialCleanup).to receive(:new).and_call_original
          expect(block.call).to be_instance_of(Jobs::Runtime::ServiceOperationsInitialCleanup)
        end

        schedule.start
      end

      it 'schedules the frequent inline jobs' do
        allow_any_instance_of(CloudController::DependencyLocator).to receive(:statsd_client).and_return(instance_double(Statsd))
        allow(clock).to receive(:schedule_daily_job)
        allow(clock).to receive(:schedule_frequent_worker_job)
        expect(clock).to receive(:schedule_frequent_inline_job) do |args, &block|
          expect(args).to eql(name: 'diego_sync', interval: 30, timeout: global_timeout)
          expect(Jobs::Diego::Sync).to receive(:new).with(no_args).and_call_original
          expect(block.call).to be_instance_of(Jobs::Diego::Sync)
        end

        schedule.start
      end

      context 'when the diego sync frequency is zero' do
        before do
          TestConfig.override(
            diego_sync: { frequency_in_seconds: 0 }
          )
        end

        it 'does not run diego sync' do
          allow(clock).to receive(:schedule_daily_job)
          allow(clock).to receive(:schedule_frequent_worker_job)
          expect(clock).not_to receive(:schedule_frequent_inline_job)

          schedule.start
        end
      end
    end
  end
end
