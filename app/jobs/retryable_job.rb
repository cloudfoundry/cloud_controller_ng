module VCAP::CloudController
  module Jobs
    class RetryableJob
      attr_reader :job, :num_attempts

      def initialize(job, num_attempts=0)
        @job = job
        @num_attempts = num_attempts
      end

      def perform
        job.perform
      rescue VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerApiTimeout, VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerBadResponse => e
        raise e if num_attempts >= 10
        Delayed::Job.enqueue(RetryableJob.new(job, num_attempts + 1), queue: 'cc-generic', run_at: Delayed::Job.db_time_now + (2**num_attempts).minutes)
      end

      def max_attempts
        # We don't want DelayedJob to handle the retry logic, because we only want to perform
        # retries for specific failures. We'll handle retry and num_attempts separately.
        1
      end
    end
  end
end
