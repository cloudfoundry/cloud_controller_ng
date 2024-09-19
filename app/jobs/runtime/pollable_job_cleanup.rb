module VCAP::CloudController
  module Jobs
    module Runtime
      class PollableJobCleanup < VCAP::CloudController::Jobs::CCJob
        attr_accessor :cutoff_age_in_days

        def initialize(cutoff_age_in_days)
          @cutoff_age_in_days = cutoff_age_in_days
        end

        def perform
          old_pollable_jobs = PollableJobModel.where(Sequel.lit("created_at < CURRENT_TIMESTAMP - INTERVAL '?' DAY", cutoff_age_in_days))
          logger = Steno.logger('cc.background.pollable-job-cleanup')
          logger.info("Cleaning up #{old_pollable_jobs.count} Jobs rows")
          old_pollable_jobs.delete
        end

        def job_name_in_configuration
          :pollable_job_cleanup
        end

        def max_attempts
          1
        end
      end
    end
  end
end
