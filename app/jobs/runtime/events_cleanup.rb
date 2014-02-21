module VCAP::CloudController
  module Jobs
    module Runtime
      class EventsCleanup < Struct.new(:cutoff_age_in_days)
        def perform
          old_events = Event.where("created_at < ?", cutoff_time)
          logger = Steno.logger("cc.background")
          logger.info("Cleaning up #{old_events.count} Event rows")
          old_events.delete
        end

        def job_name_in_configuration
          :events_cleanup
        end

        private

        def cutoff_time
          Time.now - cutoff_age_in_days.days
        end
      end
    end
  end
end
