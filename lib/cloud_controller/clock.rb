require 'clockwork'

module VCAP::CloudController
  class Clock
    def initialize(config)
      @config = config
      @logger = Steno.logger('cc.clock')
    end

    def start
      schedule_cleanup(:app_usage_events, Jobs::Runtime::AppUsageEventsCleanup, '18:00')
      schedule_cleanup(:app_events, Jobs::Runtime::AppEventsCleanup, '19:00')
      schedule_cleanup(:audit_events, Jobs::Runtime::EventsCleanup, '20:00')
      schedule_cleanup(:failed_jobs, Jobs::Runtime::FailedJobsCleanup, '21:00')
      schedule_frequent_cleanup(:pending_packages, Jobs::Runtime::PendingPackagesCleanup)

      Clockwork.run
    end

    private

    def schedule_cleanup(name, klass, at)
      Clockwork.every(1.day, "#{name}.cleanup.job", at: at) do |_|
        @logger.info("Queueing #{klass} at #{Time.now.utc}")
        cutoff_age_in_days = @config.fetch(name.to_sym).fetch(:cutoff_age_in_days)
        job = klass.new(cutoff_age_in_days)
        Jobs::Enqueuer.new(job, queue: 'cc-generic').enqueue
      end
    end

    def schedule_frequent_cleanup(name, klass)
      config = @config.fetch(name.to_sym)

      Clockwork.every(config.fetch(:frequency_in_seconds), "#{name}.cleanup.job") do |_|
        @logger.info("Queueing #{klass} at #{Time.now.utc}")
        expiration = config.fetch(:expiration_in_seconds)
        job = klass.new(expiration)
        Jobs::Enqueuer.new(job, queue: 'cc-generic').enqueue
      end
    end
  end
end
