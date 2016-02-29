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
      @clock = Clock.new(config)
    end

    def start
      CLEANUPS.each { |c| @clock.schedule_cleanup(c[:name], c[:class], c[:time]) }

      @clock.schedule_frequent_cleanup(:pending_packages, Jobs::Runtime::PendingPackagesCleanup)

      Clockwork.run
    end
  end
end
