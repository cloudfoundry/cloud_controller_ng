module VCAP::CloudController
  module Jobs
    class TimeoutJob < VCAP::CloudController::Jobs::CCJob
      attr_accessor :job

      def initialize(job)
        @job = job
      end

      def perform
        Timeout.timeout max_run_time(job.job_name_in_configuration) do
          job.perform
        end
      rescue Timeout::Error
        raise VCAP::Errors::ApiError.new_from_details('JobTimeout')
      end

      def max_attempts
        job.max_attempts
      end

      def max_run_time(job_name_in_configuration)
        jobs_config = VCAP::CloudController::Config.config[:jobs]
        job_config = jobs_config[job_name_in_configuration] || jobs_config[:global]
        job_config[:timeout_in_seconds]
      end

      def reschedule_at(time, attempts)
        job.reschedule_at(time, attempts)
      end
    end
  end
end
