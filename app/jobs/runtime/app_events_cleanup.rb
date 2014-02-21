module VCAP::CloudController
  module Jobs
    module Runtime
      class AppEventsCleanup < Struct.new(:cutoff_age_in_days)

        def perform
          old_app_events = AppEvent.where("created_at < ?", cutoff_time)
          logger = Steno.logger("cc.background")
          logger.info("Cleaning up #{old_app_events.count} AppEvent rows")
          old_app_events.delete
        end

        def job_name_in_configuration
          :app_events_cleanup
        end

        private

        def cutoff_time
          Time.now - cutoff_age_in_days.days
        end
      end
    end
  end
end
