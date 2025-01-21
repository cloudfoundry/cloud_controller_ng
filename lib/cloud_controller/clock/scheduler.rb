require 'clockwork'
require 'cloud_controller/clock/clock'
require 'cloud_controller/clock/job_timeout_calculator'

module VCAP::CloudController
  class Scheduler
    CLEANUPS = [
      { name: 'app_usage_events', class: Jobs::Runtime::AppUsageEventsCleanup, time: '18:00',
        arg_from_config: [%i[app_usage_events cutoff_age_in_days], %i[app_usage_events threshold_for_keeping_unprocessed_records]] },
      { name: 'audit_events', class: Jobs::Runtime::EventsCleanup, time: '20:00', arg_from_config: %i[audit_events cutoff_age_in_days] },
      { name: 'service_usage_events', class: Jobs::Services::ServiceUsageEventsCleanup, time: '22:00',
        arg_from_config: [%i[service_usage_events cutoff_age_in_days], %i[service_usage_events threshold_for_keeping_unprocessed_records]] },
      { name: 'completed_tasks', class: Jobs::Runtime::PruneCompletedTasks, time: '23:00', arg_from_config: %i[completed_tasks cutoff_age_in_days] },
      { name: 'expired_blob_cleanup', class: Jobs::Runtime::ExpiredBlobCleanup, time: '00:00' },
      { name: 'expired_resource_cleanup', class: Jobs::Runtime::ExpiredResourceCleanup, time: '00:30' },
      { name: 'expired_orphaned_blob_cleanup', class: Jobs::Runtime::ExpiredOrphanedBlobCleanup, time: '01:00' },
      { name: 'orphaned_blobs_cleanup', class: Jobs::Runtime::OrphanedBlobsCleanup, time: '01:30', priority: Clock::MEDIUM_PRIORITY },
      { name: 'pollable_job_cleanup', class: Jobs::Runtime::PollableJobCleanup, time: '02:00', arg_from_config: %i[pollable_jobs cutoff_age_in_days] },
      { name: 'prune_completed_deployments', class: Jobs::Runtime::PruneCompletedDeployments, time: '03:00', arg_from_config: [:max_retained_deployments_per_app] },
      { name: 'prune_completed_builds', class: Jobs::Runtime::PruneCompletedBuilds, time: '03:30', arg_from_config: [:max_retained_builds_per_app] },
      { name: 'prune_excess_app_revisions', class: Jobs::Runtime::PruneExcessAppRevisions, time: '03:35', arg_from_config: [:max_retained_revisions_per_app] }
    ].freeze

    FREQUENTS = [
      { name: 'pending_droplets', class: Jobs::Runtime::PendingDropletCleanup },
      { name: 'pending_builds', class: Jobs::Runtime::PendingBuildCleanup },
      { name: 'failed_jobs', class: Jobs::Runtime::FailedJobsCleanup },
      { name: 'service_operations_initial_cleanup', class: Jobs::Runtime::ServiceOperationsInitialCleanup }
    ].freeze

    def initialize(config)
      @clock = Clock.new
      @config = config
      @logger = Steno.logger('cc.clock')
      @timeout_calculator = JobTimeoutCalculator.new(@config)
      Thread.abort_on_exception = true
    end

    def start
      start_daily_jobs
      start_frequent_jobs
      start_inline_jobs

      Clockwork.error_handler do |error|
        @logger.error("#{error} (#{error.class.name})")
        raise(error)
      end

      Clockwork.run
    end

    private

    def start_inline_jobs
      return if @config.get(:diego_sync, :frequency_in_seconds).zero?

      clock_opts = {
        name: 'diego_sync',
        interval: @config.get(:diego_sync, :frequency_in_seconds),
        timeout: @timeout_calculator.calculate(:diego_sync)
      }
      @clock.schedule_frequent_inline_job(**clock_opts) do
        Jobs::Diego::Sync.new
      end
    end

    def start_frequent_jobs
      FREQUENTS.each do |job_config|
        clock_opts = {
          name: job_config[:name],
          interval: @config.get(job_config[:name].to_sym, :frequency_in_seconds)
        }
        @clock.schedule_frequent_worker_job(**clock_opts) do
          klass = job_config[:class]
          klass.new(**@config.get(job_config[:name].to_sym).reject { |k| [:frequency_in_seconds].include?(k) })
        end
      end
    end

    def start_daily_jobs
      CLEANUPS.each do |cleanup_config|
        clock_opts = {
          name: cleanup_config[:name],
          at: cleanup_config[:time],
          priority: cleanup_config[:priority] || Clock::HIGH_PRIORITY
        }

        @clock.schedule_daily_job(**clock_opts) do
          klass = cleanup_config[:class]

          if cleanup_config[:arg_from_config]
            args = cleanup_config[:arg_from_config]
            if args.first.is_a?(Array)
              args = args.map { |arg| @config.get(*arg) }
              klass.new(*args)
            else
              klass.new(@config.get(*args))
            end
          else
            klass.new
          end
        end
      end
    end
  end
end
