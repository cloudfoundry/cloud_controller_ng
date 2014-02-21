module VCAP::CloudController
  module Jobs
    class TimeoutJob < Struct.new(:job)
      def perform
        Timeout.timeout max_run_time(job.job_name_in_configuration) do
          job.perform
        end
      rescue Timeout::Error => e
        raise VCAP::Errors::JobTimeout
      end

      def max_run_time(job_name_in_configuration)
        jobs_config = VCAP::CloudController::Config.config[:jobs]
        job_config = jobs_config[job_name_in_configuration] || jobs_config[:global]
        job_config[:timeout_in_seconds]
      end
    end
  end
end