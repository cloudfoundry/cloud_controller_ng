require 'clockwork'
require 'cloud_controller/clock'

module VCAP::CloudController
  class Scheduler
    CLEANUPS = [
      { name: :app_usage_events, class: Jobs::Runtime::AppUsageEventsCleanup, time: '18:00' },
      { name: :app_events, class: Jobs::Runtime::AppEventsCleanup, time: '19:00' },
      { name: :audit_events, class: Jobs::Runtime::EventsCleanup, time: '20:00' },
      { name: :failed_jobs, class: Jobs::Runtime::FailedJobsCleanup, time: '21:00' },
      { name: :service_usage_events, class: Jobs::Services::ServiceUsageEventsCleanup, time: '22:00' },
      { name: :completed_tasks, class: Jobs::Runtime::PruneCompletedTasks, time: '23:00' },
    ].freeze

    def initialize(config)
      @clock  = Clock.new(config)
      @logger = Steno.logger('cc.clock')
    end

    def start
      CLEANUPS.each { |c| @clock.schedule_cleanup(c[:name], c[:class], c[:time]) }
      @clock.schedule_frequent_job(:pending_droplets, Jobs::Runtime::PendingDropletCleanup)
      @clock.schedule_daily(:expired_blob_cleanup, Jobs::Runtime::ExpiredBlobCleanup, '00:00')
      @clock.schedule_frequent_job(:diego_sync, Jobs::Diego::Sync, priority: -10, queue: 'sync-queue', allow_only_one_job_in_queue: true)

      Clockwork.error_handler { |error| @logger.error(error) }
      Clockwork.run
    end
  end
end
