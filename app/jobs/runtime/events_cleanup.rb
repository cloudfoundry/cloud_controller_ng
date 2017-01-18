module VCAP::CloudController
  module Jobs
    module Runtime
      class EventsCleanup < VCAP::CloudController::Jobs::CCJob
        attr_accessor :cutoff_age_in_days

        def initialize(cutoff_age_in_days)
          @cutoff_age_in_days = cutoff_age_in_days
        end

        def perform
          if App.db.database_type == :mssql
            old_events = Event.where("created_at < DATEADD(DAY, -?, CURRENT_TIMESTAMP)", cutoff_age_in_days.to_i)
          else
            old_events = Event.where("created_at < CURRENT_TIMESTAMP - INTERVAL '?' DAY", cutoff_age_in_days.to_i)
          end
          logger = Steno.logger('cc.background')
          logger.info("Cleaning up #{old_events.count} Event rows")
          old_events.delete
        end

        def job_name_in_configuration
          :events_cleanup
        end

        def max_attempts
          1
        end
      end
    end
  end
end
