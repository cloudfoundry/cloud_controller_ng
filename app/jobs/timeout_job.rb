module VCAP::CloudController
  module Jobs
    class TimeoutJob < Struct.new(:job)
      def perform
        Timeout.timeout max_run_time(job.job_name) do
          job.perform
        end
      end

      def max_run_time(job_name)
        jobs_config = VCAP::CloudController::Config.config[:jobs]
        job_config = jobs_config[job_name] || jobs_config[:global]
        job_config[:timeout_in_seconds]
      end
    end
  end
end