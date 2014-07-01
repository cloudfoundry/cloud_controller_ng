require "clockwork"

module VCAP::CloudController
  class Clock
    def initialize(config)
      @config = config
      @logger = Steno.logger("cc.clock")
    end

    def start
      schedule_cleanup(:app_usage_events, Jobs::Runtime::AppUsageEventsCleanup, "18:00")
      schedule_cleanup(:app_events, Jobs::Runtime::AppEventsCleanup, "19:00")
      schedule_cleanup(:audit_events, Jobs::Runtime::EventsCleanup, "20:00")
      schedule_cleanup(:failed_jobs, Jobs::Runtime::FailedJobsCleanup, "21:00")

      Clockwork.run
    end

    private

    def schedule_cleanup(name, klass, at)
      Clockwork.every(1.day, "#{name}.cleanup.job", at: at) do |_|
        @logger.info("Queueing #{klass} at #{Time.now}")
        cutoff_age_in_days = @config.fetch(name.to_sym).fetch(:cutoff_age_in_days)
        job = klass.new(cutoff_age_in_days)
        Jobs::Enqueuer.new(job, queue: "cc-generic").enqueue()
      end
    end
  end
end
