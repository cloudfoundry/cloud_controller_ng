module VCAP::CloudController
  module Jobs
    module Runtime
      class AppEventsCleanup < VCAP::CloudController::Jobs::CCJob
        attr_accessor :cutoff_age_in_days

        def initialize(cutoff_age_in_days)
          @cutoff_age_in_days = cutoff_age_in_days
        end

        def perform
          if App.db.database_type == :mssql
            old_app_events = AppEvent.where("created_at < DATEADD(DAY, -?, CURRENT_TIMESTAMP)", cutoff_age_in_days.to_i)
          else
            old_app_events = AppEvent.where("created_at < CURRENT_TIMESTAMP - INTERVAL '?' DAY", cutoff_age_in_days.to_i)
          end
          logger = Steno.logger('cc.background')
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
