require 'clockwork'

module VCAP::CloudController
  module Jobs
    class JobTimeoutCalculator
      def initialize(config)
        @config = config
      end

      def calculate(job)
        job_name = job_name(job)
        config.dig(:jobs, job_name.to_sym, :timeout_in_seconds) || config.dig(:jobs, :global, :timeout_in_seconds)
      end

      private

      attr_reader :config

      def job_name(job)
        job.try(:job_name_in_configuration) || :global
      end
    end

    class Enqueuer
      def initialize(job, opts={})
        @job = job
        @opts = opts
        @timeout_calculator = JobTimeoutCalculator.new(VCAP::CloudController::Config.config)
      end

      def enqueue
        request_id = ::VCAP::Request.current_id
        Delayed::Job.enqueue(ExceptionCatchingJob.new(RequestJob.new(TimeoutJob.new(@job, job_timeout), request_id)), @opts)
      end

      def run_inline
        run_immediately do
          Delayed::Job.enqueue(@job, @opts)
        end
      end

      private

      def job_timeout
        @timeout_calculator.calculate(@job)
      end

      def run_immediately
        cache = Delayed::Worker.delay_jobs
        Delayed::Worker.delay_jobs = false
        yield
      ensure
        Delayed::Worker.delay_jobs = cache
      end
    end
  end
end
