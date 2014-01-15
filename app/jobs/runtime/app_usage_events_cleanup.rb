module VCAP::CloudController
  module Jobs
    module Runtime
      class AppUsageEventsCleanup < Struct.new(:cutoff_age_in_days)
        include VCAP::CloudController::TimedJob

        def perform
          Timeout.timeout max_run_time(:app_usage_events_cleanup) do
            old_app_usage_events = AppUsageEvent.dataset.where("created_at < ?", cutoff_time)
            logger = Steno.logger("cc.background")
            logger.info("Cleaning up  AppUsageEvent #{old_app_usage_events.count} rows")
            old_app_usage_events.delete
          end
        end

        private

        def cutoff_time
          Time.now - cutoff_age_in_days.days
        end
      end
    end
  end
end
