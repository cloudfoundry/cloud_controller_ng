module VCAP::CloudController
  module Jobs
    class TimeoutJob < WrappingJob
      def perform
        name = @handler.respond_to?(:job_name_in_configuration) ? @handler.job_name_in_configuration : :global
        Timeout.timeout max_run_time(name) do
          super
        end
      rescue Timeout::Error
        raise @handler.timeout_error if @handler.respond_to?(:timeout_error)
        raise VCAP::Errors::ApiError.new_from_details('JobTimeout')
      end

      def max_run_time(job_name_in_configuration)
        jobs_config = VCAP::CloudController::Config.config[:jobs]
        job_config = jobs_config[job_name_in_configuration] || jobs_config[:global]
        job_config[:timeout_in_seconds]
      end

      # TODO: fix bad tests that grab this
      def job
        @handler
      end
    end
  end
end
