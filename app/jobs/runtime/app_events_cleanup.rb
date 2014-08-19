module VCAP::CloudController
  module Jobs
    module Runtime
      class AppEventsCleanup < Struct.new(:cutoff_age_in_days)

        def perform
          old_app_events = AppEvent.where("created_at < CURRENT_TIMESTAMP - INTERVAL '? DAY'", cutoff_age_in_days)
          logger = Steno.logger("cc.background")
          logger.info("Cleaning up #{old_app_events.count} AppEvent rows")
          old_app_events.delete
        end

        def job_name_in_configuration
          :app_events_cleanup
        end

        def max_attempts
          1
        end
      end
    end
  end
end
