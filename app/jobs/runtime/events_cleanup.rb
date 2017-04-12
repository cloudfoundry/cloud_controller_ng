require 'jobs/common_events_cleanup'
module VCAP::CloudController
  module Jobs
    module Runtime
      class EventsCleanup < VCAP::CloudController::CommonEventsCleanUp
        def initialize(cutoff_age_in_days)
          @cutoff_age_in_days = cutoff_age_in_days
          @event_model = Event
          @job_name = :events_cleanup
        end
      end
    end
  end
end
