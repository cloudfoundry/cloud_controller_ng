require 'clockwork'
require 'cloud_controller/clock/job_timeout_calculator'
require 'cloud_controller/job/job_priority_overwriter'
require 'jobs/pollable_job_wrapper'
require 'jobs/logging_context_job'
require 'jobs/timeout_job'
require 'securerandom'

module VCAP::CloudController
  module Jobs
    class Enqueuer
      def initialize(opts={})
        @opts = opts
        @timeout_calculator = JobTimeoutCalculator.new(VCAP::CloudController::Config.config)
        @priority_overwriter = JobPriorityOverwriter.new(VCAP::CloudController::Config.config)
        load_delayed_job_plugins
      end

      def enqueue(job, run_at: nil, priority_increment: nil)
        enqueue_job(job, run_at:, priority_increment:)
      end

      def enqueue_pollable(job, existing_guid: nil, run_at: nil, priority_increment: nil)
        wrapped_job = PollableJobWrapper.new(job, existing_guid:)

        wrapped_job = yield wrapped_job if block_given?

        delayed_job = enqueue_job(wrapped_job, run_at:, priority_increment:)
        PollableJobModel.find_by_delayed_job(delayed_job)
      end

      def run_inline(job)
        run_immediately do
          Delayed::Job.enqueue(TimeoutJob.new(job, job_timeout(job)), @opts)
        end
      end

      private

      def enqueue_job(job, run_at: nil, priority_increment: nil)
        @opts['guid'] = SecureRandom.uuid
        request_id = ::VCAP::Request.current_id
        timeout_job = TimeoutJob.new(job, job_timeout(job))
        logging_context_job = LoggingContextJob.new(timeout_job, request_id)

        priority_from_config = get_overwritten_job_priority_from_config(job) || 0
        base_priority = @opts[:priority] || 0
        final_priority = if priority_increment
                           base_priority + priority_from_config + [priority_increment, 0].max
                         else
                           base_priority + priority_from_config
                         end

        local_opts = {}
        local_opts[:priority] = final_priority if final_priority > 0
        local_opts[:run_at] = run_at if run_at

        Delayed::Job.enqueue(logging_context_job, @opts.merge(local_opts))
      end

      def load_delayed_job_plugins
        @load_delayed_job_plugins ||= Delayed::Worker.new
      end

      def job_timeout(job)
        unwrapped_job = unwrap_job(job)
        return @timeout_calculator.calculate(unwrapped_job.try(:job_name_in_configuration), @opts[:queue]) if @opts[:queue]

        @timeout_calculator.calculate(unwrapped_job.try(:job_name_in_configuration))
      end

      def get_overwritten_job_priority_from_config(job)
        unwrapped_job = unwrap_job(job)
        @priority_overwriter.get(unwrapped_job.try(:display_name)) ||
          @priority_overwriter.get(unwrapped_job.try(:job_name_in_configuration)) ||
          @priority_overwriter.get(unwrapped_job.class.name)
      end

      def unwrap_job(job)
        job.is_a?(PollableJobWrapper) ? job.handler : job
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
