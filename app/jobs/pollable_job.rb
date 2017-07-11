module VCAP::CloudController
  module Jobs
    class PollableJob < WrappingJob
      # use custom hook as Job does not have the guid field populated during the normal `enqueue` hook
      def after_enqueue(job)
        PollableJobModel.create(
          delayed_job_guid: job.guid,
          state: PollableJobModel::PROCESSING_STATE,
          operation: @handler.display_name,
          resource_guid: @handler.resource_guid,
          resource_type: @handler.resource_type
        )
      end

      def success(job)
        change_state(job, PollableJobModel::COMPLETE_STATE)
      end

      def failure(job)
        change_state(job, PollableJobModel::FAILED_STATE)
      end

      private

      def change_state(job, new_state)
        PollableJobModel.where(delayed_job_guid: job.guid).update(state: new_state)
      end
    end
  end
end
