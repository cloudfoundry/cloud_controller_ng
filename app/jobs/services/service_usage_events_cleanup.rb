require 'jobs/common_events_cleanup'
require 'repositories/service_usage_event_repository'

module VCAP::CloudController
  module Jobs
    module Services
      class ServiceUsageEventsCleanup < VCAP::CloudController::CommonEventsCleanUp
        def initialize(cutoff_age_in_days)
          @cutoff_age_in_days = cutoff_age_in_days
          @event_model = ServiceUsageEvent
          @job_name = :service_usage_events_cleanup
        end
      end
    end
  end
end
