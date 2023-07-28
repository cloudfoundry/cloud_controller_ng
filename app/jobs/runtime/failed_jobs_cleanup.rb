module VCAP::CloudController
  module Jobs
    module Runtime
      class FailedJobsCleanup < VCAP::CloudController::Jobs::CCJob
        attr_accessor :cutoff_age_in_days, :max_number_of_failed_delayed_jobs

        def initialize(cutoff_age_in_days:, max_number_of_failed_delayed_jobs: nil)
          @cutoff_age_in_days = cutoff_age_in_days
          @max_number_of_failed_delayed_jobs = max_number_of_failed_delayed_jobs
        end

        def perform
          old_delayed_jobs = Delayed::Job.
                             where(Sequel.lit('failed_at is not null')).
                             where(Sequel.lit('failed_at >= run_at')).
                             where(Sequel.lit("run_at < CURRENT_TIMESTAMP - INTERVAL '?' DAY", cutoff_age_in_days.to_i))

          logger = Steno.logger('cc.background')
          logger.info("Cleaning up #{old_delayed_jobs.count} old Failed Delayed Jobs")

          old_delayed_jobs.delete

          unless max_number_of_failed_delayed_jobs.nil?
            ids_exceeding_limit = Delayed::Job.
                                  where(Sequel.lit('failed_at is not null')).
                                  order(Sequel.desc(:id)).
                                  offset(max_number_of_failed_delayed_jobs.to_i).
                                  # Mysql handles offset differently, therefore using a large
                                  # number to mimic unlimited offset
                                  limit(1844674407370955161).
                                  select(:id)

            logger.info("Cleaning up #{ids_exceeding_limit.count} Failed Delayed Jobs because they exceed max_number_of_failed_delayed_jobs")

            Delayed::Job.where(id: ids_exceeding_limit).delete
          end
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
