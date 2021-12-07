module VCAP::CloudController
  module Jobs
    module Runtime
      class PollableJobCleanup < VCAP::CloudController::Jobs::CCJob
        CUTOFF_AGE_IN_DAYS = 90

        def perform
          old_pollable_jobs = PollableJobModel.where(Sequel.lit("created_at < CURRENT_TIMESTAMP - INTERVAL '?' DAY", CUTOFF_AGE_IN_DAYS))
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
