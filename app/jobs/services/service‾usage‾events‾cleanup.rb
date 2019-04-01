require 'repositories/service_usage_event_repository'

module VCAP::CloudController
  module Jobs
    module Services
      class ServiceUsageEventsCleanup < VCAP::CloudController::Jobs::CCJob
        attr_accessor :cutoff_age_in_days

        def initialize(cutoff_age_in_days)
          @cutoff_age_in_days = cutoff_age_in_days
        end

        def perform
          logger = Steno.logger('cc.background')
          logger.info('Cleaning up old ServiceUsageEvent rows')

          repository = Repositories::ServiceUsageEventRepository.new
          deleted_count = repository.delete_events_older_than(cutoff_age_in_days)

          logger.info("Cleaned up #{deleted_count} ServiceUsageEvent rows")
        end

        def job_name_in_configuration
          :service_usage_events_cleanup
        end

        def max_attempts
          1
        end
      end
    end
  end
end
