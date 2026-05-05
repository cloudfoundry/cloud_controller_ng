module VCAP::CloudController
  module Jobs
    module RootJobMixin
      private

      def my_pollable_job
        PollableJobModel.find(
          resource_guid: resource_guid,
          operation: display_name,
          state: [PollableJobModel::PROCESSING_STATE, PollableJobModel::POLLING_STATE]
        )
      end

      def my_pollable_job_guid
        my_pollable_job&.guid
      end

      def enqueue_sub_job(job)
        Jobs::GenericEnqueuer.shared.enqueue_pollable(job, root_job_guid: my_pollable_job_guid)
      end

      # Returns true if any child jobs are still running. Raises if any have failed.
      def sub_jobs_pending?
        parent = my_pollable_job
        return false unless parent

        children = parent.sub_jobs_dataset
        return false unless children.any?

        raise_sub_job_failure if children.where(state: PollableJobModel::FAILED_STATE).any?

        children.where(state: [PollableJobModel::PROCESSING_STATE, PollableJobModel::POLLING_STATE]).any?
      end

      def raise_sub_job_failure
        failed_jobs = my_pollable_job.sub_jobs_dataset.where(state: PollableJobModel::FAILED_STATE).all
        details = failed_jobs.map { |j| "#{j.operation} #{j.resource_guid}" }.join(', ')
        raise CloudController::Errors::ApiError.new_from_details(
          'SpaceDeletionFailed',
          resource_guid,
          "Child job(s) failed: #{details}"
        )
      end
    end
  end
end
