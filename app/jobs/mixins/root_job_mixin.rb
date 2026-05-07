module VCAP::CloudController
  module Jobs
    module RootJobMixin
      private

      def root_job
        PollableJobModel.find(
          resource_guid: resource_guid,
          operation: display_name,
          state: [PollableJobModel::PROCESSING_STATE, PollableJobModel::POLLING_STATE]
        )
      end

      def activate_root_job_context
        job = root_job
        counts = sub_job_state_counts(job)
        Jobs::GenericEnqueuer.shared.activate_root_context(root_job_guid: job&.guid, sub_job_counts: counts)
      end

      def deactivate_root_job_context
        Jobs::GenericEnqueuer.shared.deactivate_root_context
      end

      def sub_jobs_pending?
        enqueuer = Jobs::GenericEnqueuer.shared
        return false if enqueuer.sub_jobs_active.zero? && enqueuer.sub_jobs_failed.zero?

        if enqueuer.sub_jobs_active.positive?
          warn_about_failed_sub_jobs if enqueuer.sub_jobs_failed.positive?
          return true
        end

        raise_sub_job_failure if enqueuer.sub_jobs_failed.positive?
        false
      end

      def warn_about_failed_sub_jobs
        @warnings ||= []
        @warnings << { detail: 'One or more sub-jobs have failed. Waiting for remaining operations to complete before reporting.' }
      end

      def raise_sub_job_failure
        job = root_job
        failed_jobs = job.sub_jobs_dataset.where(state: PollableJobModel::FAILED_STATE).all
        details = failed_jobs.map { |j| "#{j.operation} #{j.resource_guid}" }.join(', ')
        raise CloudController::Errors::ApiError.new_from_details(
          'SpaceDeletionFailed', resource_guid, "Sub-job(s) failed: #{details}"
        )
      end

      def sub_job_state_counts(job)
        return {} unless job

        counts = job.sub_jobs_dataset.group_and_count(:state).as_hash(:state, :count)
        {
          active: (counts[PollableJobModel::PROCESSING_STATE] || 0) + (counts[PollableJobModel::POLLING_STATE] || 0),
          failed: counts[PollableJobModel::FAILED_STATE] || 0,
          completed: counts[PollableJobModel::COMPLETE_STATE] || 0
        }
      end
    end
  end
end
