require 'jobs/common_events_cleanup'
require 'repositories/app_usage_event_repository'

module VCAP::CloudController
  module Jobs
    module Runtime
      class AppUsageEventsCleanup < VCAP::CloudController::CommonEventsCleanUp
        def initialize(cutoff_age_in_days)
          @cutoff_age_in_days = cutoff_age_in_days
          @event_model = AppUsageEvent
          @job_name = :app_usage_events_cleanup
        end
      end
    end
  end
end
