require 'clockwork'
require 'cloud_controller/clock/job_timeout_calculator'
require 'jobs/pollable_job_wrapper'
require 'jobs/logging_context_job'
require 'jobs/timeout_job'
require 'securerandom'

module VCAP::CloudController
  module Jobs
    class Enqueuer
      def initialize(job, opts={})
        @job = job
        @opts = opts
        @timeout_calculator = JobTimeoutCalculator.new(VCAP::CloudController::Config.config)
        load_delayed_job_plugins
      end

      def enqueue
        enqueue_job(@job)
      end

      def enqueue_pollable(existing_guid: nil)
        wrapped_job = PollableJobWrapper.new(@job, existing_guid: existing_guid)

        if block_given?
          wrapped_job = yield wrapped_job
        end

        delayed_job = enqueue_job(wrapped_job)
        PollableJobModel.find_by_delayed_job(delayed_job)
      end

      def run_inline
        run_immediately do
          Delayed::Job.enqueue(TimeoutJob.new(@job, job_timeout), @opts)
        end
      end

      private

      def enqueue_job(job)
        @opts['guid'] = SecureRandom.uuid
        request_id = ::VCAP::Request.current_id
        timeout_job = TimeoutJob.new(job, job_timeout)
        logging_context_job = LoggingContextJob.new(timeout_job, request_id)
        Delayed::Job.enqueue(logging_context_job, @opts)
      end

      def load_delayed_job_plugins
        @load_delayed_job_plugins ||= Delayed::Worker.new
      end

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
