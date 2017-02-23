require 'clockwork'
require 'cloud_controller/clock/job_timeout_calculator'

module VCAP::CloudController
  module Jobs
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
          Delayed::Job.enqueue(TimeoutJob.new(@job, job_timeout), @opts)
        end
      end

      private

      def job_timeout
        @timeout_calculator.calculate(@job.try(:job_name_in_configuration))
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
