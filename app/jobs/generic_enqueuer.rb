module VCAP::CloudController
  module Jobs
    REDUCED_PRIORITY = 50

    class GenericEnqueuer < Enqueuer
      attr_accessor :root_job_guid
      attr_reader :sub_jobs_active, :sub_jobs_failed, :sub_jobs_completed

      def self.shared(priority: nil)
        stored_instance = Thread.current[:generic_enqueuer]
        return stored_instance if stored_instance && priority.nil?

        new_instance = new(queue: Jobs::Queues.generic, priority: priority)
        Thread.current[:generic_enqueuer] ||= new_instance
        new_instance
      end

      def self.reset!
        Thread.current[:generic_enqueuer] = nil
      end

      def initialize(**opts)
        super
        reset_sub_job_state
      end

      def activate_root_context(root_job_guid:, sub_job_counts: {})
        @root_job_guid = root_job_guid
        @sub_jobs_active = sub_job_counts.fetch(:active, 0)
        @sub_jobs_failed = sub_job_counts.fetch(:failed, 0)
        @sub_jobs_completed = sub_job_counts.fetch(:completed, 0)
      end

      def deactivate_root_context
        @root_job_guid = nil
        reset_sub_job_state
      end

      def sub_job_count
        @sub_jobs_active
      end

      def enqueue_pollable(job, existing_guid: nil, run_at: nil, priority_increment: nil, preserve_priority: false)
        result = super
        @sub_jobs_active += 1 if root_job_guid
        result
      end

      private

      def reset_sub_job_state
        @sub_jobs_active = 0
        @sub_jobs_failed = 0
        @sub_jobs_completed = 0
      end
    end
  end
end
