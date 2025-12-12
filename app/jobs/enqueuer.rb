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

      def enqueue_pollable(job, existing_guid: nil, run_at: nil, priority_increment: nil, preserve_priority: false)
        wrapped_job = PollableJobWrapper.new(job, existing_guid:)

        wrapped_job = yield wrapped_job if block_given?

        delayed_job = enqueue_job(wrapped_job, run_at:, priority_increment:, preserve_priority:)
        PollableJobModel.find_by_delayed_job(delayed_job)
      end

      def self.unwrap_job(job)
        job.is_a?(WrappingJob) ? unwrap_job(job.handler) : job
      end

      private

      def enqueue_job(job, run_at: nil, priority_increment: nil, preserve_priority: false)
        @opts['guid'] = SecureRandom.uuid
        request_id = ::VCAP::Request.current_id
        timeout_job = TimeoutJob.new(job, job_timeout(job))
        logging_context_job = LoggingContextJob.new(timeout_job, request_id)

        base_priority = @opts[:priority] || 0
        priority_from_config = get_overwritten_job_priority_from_config(job) || 0

        final_priority = base_priority
        final_priority += priority_from_config unless preserve_priority
        final_priority += [priority_increment, 0].max if priority_increment && !preserve_priority

        local_opts = {}
        # DelayedJob might have a different default priority. In the context of the enqueuer, we consider 0 as the default priority.
        # Thus, we only set the priority if we use a non-default priority.
        local_opts[:priority] = final_priority if final_priority > 0
        local_opts[:run_at] = run_at if run_at

        Delayed::Job.enqueue(logging_context_job, @opts.merge(local_opts))
      end

      def load_delayed_job_plugins
        @load_delayed_job_plugins ||= Delayed::Worker.new
      end

      def job_timeout(job)
        unwrapped_job = self.class.unwrap_job(job)
        return @timeout_calculator.calculate(unwrapped_job.try(:job_name_in_configuration), @opts[:queue]) if @opts[:queue]

        @timeout_calculator.calculate(unwrapped_job.try(:job_name_in_configuration))
      end

      def get_overwritten_job_priority_from_config(job)
        unwrapped_job = self.class.unwrap_job(job)
        @priority_overwriter.get(unwrapped_job.try(:display_name)) ||
          @priority_overwriter.get(unwrapped_job.try(:job_name_in_configuration)) ||
          @priority_overwriter.get(unwrapped_job.class.name)
      end
    end
  end
end
