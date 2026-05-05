module VCAP::CloudController
  module Jobs
    module ParentJobMixin
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

      def enqueue_child(job)
        Jobs::GenericEnqueuer.shared.enqueue_pollable(job, parent_guid: my_pollable_job_guid)
      end

      # Returns true if any child jobs are still running. Raises if any have failed.
      def children_waiting?
        parent = my_pollable_job
        return false unless parent

        children = parent.children_dataset
        return false unless children.any?

        raise_child_failure if children.where(state: PollableJobModel::FAILED_STATE).any?

        children.where(state: [PollableJobModel::PROCESSING_STATE, PollableJobModel::POLLING_STATE]).any?
      end

      def raise_child_failure
        failed_jobs = my_pollable_job.children_dataset.where(state: PollableJobModel::FAILED_STATE).all
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
