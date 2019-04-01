require 'jobs/wrapping_job'

module VCAP::CloudController
  module Jobs
    class TimeoutJob < WrappingJob
      def initialize(job, timeout)
        super(job)
        @timeout = timeout
      end

      def perform
        Timeout.timeout @timeout do
          super
        end
      rescue Timeout::Error
        raise @handler.timeout_error if @handler.respond_to?(:timeout_error)

        raise CloudController::Errors::ApiError.new_from_details('JobTimeout')
      end

      # Per DelayedJob docs: once max_run_time is reached, if a job is still locked the lock can be hijacked by another worker
      def max_run_time
        @timeout
      end

      attr_reader :timeout

      def job
        @handler
      end
    end
  end
end
