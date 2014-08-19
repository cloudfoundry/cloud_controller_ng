module VCAP::CloudController
  module Jobs
    module Runtime
      class FailedJobsCleanup < Struct.new(:cutoff_age_in_days)

        def perform
          old_delayed_jobs = Delayed::Job.
            where("failed_at is not null").
            where("failed_at >= run_at").
            where("run_at < CURRENT_TIMESTAMP - INTERVAL '? DAY'", cutoff_age_in_days)

          logger = Steno.logger("cc.background")
          logger.info("Cleaning up #{old_delayed_jobs.count} Failed Delayed Jobs")

          old_delayed_jobs.delete
        end

        def job_name_in_configuration
          :failed_jobs
        end

        def max_attempts
          1
        end
      end
    end
  end
end
