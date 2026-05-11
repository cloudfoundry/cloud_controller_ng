module VCAP::CloudController
  module Jobs
    REDUCED_PRIORITY = 50

    class GenericEnqueuer < Enqueuer
      attr_accessor :root_job_guid
      attr_reader :sub_jobs_failed, :active_sub_job_guids

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

      def activate_root_context(root_job_guid:, active_sub_job_guids: [], sub_jobs_failed: 0)
        @root_job_guid = root_job_guid
        @active_sub_job_guids = active_sub_job_guids
        @sub_jobs_failed = sub_jobs_failed
      end

      def deactivate_root_context
        @root_job_guid = nil
        reset_sub_job_state
      end

      def sub_job_count
        @active_sub_job_guids.size
      end

      def sub_jobs_active
        @active_sub_job_guids.size
      end

      def enqueue_pollable(job, existing_guid: nil, run_at: nil, priority_increment: nil, preserve_priority: false)
        result = super
        @active_sub_job_guids << result.delayed_job_guid if root_job_guid
        result
      end

      private

      def reset_sub_job_state
        @active_sub_job_guids = []
        @sub_jobs_failed = 0
      end
    end
  end
end
