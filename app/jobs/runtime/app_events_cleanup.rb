require 'jobs/common_events_cleanup'
module VCAP::CloudController
  module Jobs
    module Runtime
      class AppEventsCleanup < VCAP::CloudController::CommonEventsCleanUp
        def initialize(cutoff_age_in_days)
          @cutoff_age_in_days = cutoff_age_in_days
          @event_model = AppEvent
          @job_name = :app_events_cleanup
        end
      end
    end
  end
end
