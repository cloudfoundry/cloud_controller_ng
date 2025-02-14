module VCAP::CloudController
  module Jobs
    module Runtime
      class PollableJobCleanup < VCAP::CloudController::Jobs::CCJob
        attr_accessor :cutoff_age_in_days

        def initialize(cutoff_age_in_days)
          @cutoff_age_in_days = cutoff_age_in_days
        end

        def perform
          logger = Steno.logger('cc.background.pollable-job-cleanup')
          cutoff_condition = Sequel.lit("created_at < CURRENT_TIMESTAMP - INTERVAL '?' DAY", cutoff_age_in_days)

          old_pollable_jobs = PollableJobModel.where(cutoff_condition)
          logger.info("Cleaning up #{old_pollable_jobs.count} Jobs rows")
          old_pollable_jobs.delete

          # Job warnings have to be deleted explicitly, because
          # - we don't have a foreign key constraint and thus cannot use DELETE CASCADE, and
          # - we don't delete/destroy pollable job model objects one by one and thus cannot use hooks defined by the
          #   'destroy' association dependency between PollableJobModel and JobWarningModel.
          # Instead, we delete all expired jobs with a single SQL statement.
          #
          # By using the same cutoff condition based on 'created_at' for pollable jobs and job warnings, we ensure that
          # only job warnings are deleted where it is guaranteed that also the associated pollable job already has been
          # removed. This is due to the fact that job warnings are created after their associated pollable job, i.e.
          # pollable_job.created_at <= job_warning.created_at.
          #
          # On the other hand, it is not guaranteed that all associated job warnings are deleted for all pollable jobs
          # that have been removed during an execution of this cleanup job. But these leftovers will simply be removed
          # during the next job execution.
          old_job_warnings = JobWarningModel.where(cutoff_condition)
          logger.info("Cleaning up #{old_job_warnings.count} Job Warnings rows")
          old_job_warnings.delete
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
