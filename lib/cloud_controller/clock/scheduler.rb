require 'clockwork'
require 'cloud_controller/clock/clock'
require 'cloud_controller/clock/job_timeout_calculator'

module VCAP::CloudController
  class Scheduler
    CLEANUPS = [
      { name: 'app_usage_events', job_name: 'app_usage_events_cleanup', class: Jobs::Runtime::AppUsageEventsCleanup, time: '18:00' },
      { name: 'app_events', job_name: 'app_events_cleanup', class: Jobs::Runtime::AppEventsCleanup, time: '19:00' },
      { name: 'audit_events', job_name: 'events_cleanup', class: Jobs::Runtime::EventsCleanup, time: '20:00' },
      { name: 'failed_jobs', job_name: 'failed_jobs', class: Jobs::Runtime::FailedJobsCleanup, time: '21:00' },
      { name: 'service_usage_events', job_name: 'service_usage_events_cleanup', class: Jobs::Services::ServiceUsageEventsCleanup, time: '22:00' },
      { name: 'completed_tasks', job_name: 'prune_completed_tasks', class: Jobs::Runtime::PruneCompletedTasks, time: '23:00' },
      { name: 'expired_blob_cleanup', job_name: 'expired_blob_cleanup', class: Jobs::Runtime::ExpiredBlobCleanup, time: '00:00' },
      { name: 'expired_resource_cleanup', job_name: 'expired_resource_cleanup', class: Jobs::Runtime::ExpiredResourceCleanup, time: '00:30' },
    ].freeze

    def initialize(config)
      @clock  = Clock.new
      @config = config
      @logger = Steno.logger('cc.clock')
      @timeout_calculator = JobTimeoutCalculator.new(@config)
    end

    def start
      start_daily_jobs
      start_frequent_jobs
      start_inline_jobs

      Clockwork.error_handler { |error| @logger.error(error) }
      Clockwork.run
    end

    private

    def start_inline_jobs
      clock_opts = {
        name:     'diego_sync',
        interval: @config.dig(:diego_sync, :frequency_in_seconds),
        timeout: job_timeout(:diego_sync),
      }
      @clock.schedule_frequent_inline_job(clock_opts) do
        Jobs::Diego::Sync.new
      end
    end

    def start_frequent_jobs
      clock_opts = {
        name:     'pending_droplets',
        interval: @config.dig(:pending_droplets, :frequency_in_seconds),
      }
      @clock.schedule_frequent_worker_job(clock_opts) do
        Jobs::Runtime::PendingDropletCleanup.new(@config.dig(:pending_droplets, :expiration_in_seconds))
      end
    end

    def start_daily_jobs
      CLEANUPS.each do |cleanup_config|
        cutoff_age_in_days = @config.dig(cleanup_config[:name].to_sym, :cutoff_age_in_days)
        clock_opts = {
          name: cleanup_config[:name],
          at: cleanup_config[:time],
        }

        @clock.schedule_daily_job(clock_opts) do
          klass = cleanup_config[:class]
          cutoff_age_in_days ? klass.new(cutoff_age_in_days) : klass.new
        end
      end
    end

    def job_timeout(job_name)
      @timeout_calculator.calculate(job_name)
    end
  end
end
