require "clockwork"

module VCAP::CloudController
  class Clock

    def initialize(config)
      @config = config
    end

    def start
      logger = Steno.logger("cc.clock")
      Clockwork.every(10.minutes, "dummy.scheduled.job") do |job|
        logger.info("Would have run #{job}")
      end

      Clockwork.every(1.day, "app_usage_events.cleanup.job", at: "18:00") do |_|
        logger.info("Queueing AppUsageEventsCleanup at #{Time.now}")
        cutoff_age_in_days = @config.fetch(:app_usage_events).fetch(:cutoff_age_in_days)
        job = Jobs::Runtime::AppUsageEventsCleanup.new(cutoff_age_in_days)
        Delayed::Job.enqueue(job, queue: "cc-generic")
      end

      Clockwork.every(1.day, "app_events.cleanup.job", at: "19:00") do |_|
        logger.info("Queueing AppEventsCleanup at #{Time.now}")
        cutoff_age_in_days = @config.fetch(:app_events).fetch(:cutoff_age_in_days)
        job = Jobs::Runtime::AppEventsCleanup.new(cutoff_age_in_days)
        Delayed::Job.enqueue(job, queue: "cc-generic")
      end

      Clockwork.run
    end
  end
end
