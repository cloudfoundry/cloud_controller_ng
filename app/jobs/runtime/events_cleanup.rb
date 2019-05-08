module VCAP::CloudController
  module Jobs
    module Runtime
      class EventsCleanup < VCAP::CloudController::Jobs::CCJob
        attr_accessor :cutoff_age_in_days

        def initialize(cutoff_age_in_days)
          @cutoff_age_in_days = cutoff_age_in_days
        end

        def perform
          Database::OldRecordCleanup.new(Event, cutoff_age_in_days).delete
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
