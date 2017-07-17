require 'presenters/error_presenter'

module VCAP::CloudController
  module Jobs
    class PollableJobWrapper < WrappingJob
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

      def error(job, exception)
        api_error = convert_to_v3_api_error(exception)
        save_error(api_error, job)
      end

      def failure(job)
        change_state(job, PollableJobModel::FAILED_STATE)
      end

      private

      def convert_to_v3_api_error(exception)
        v3_hasher = V3ErrorHasher.new(exception)
        error_presenter = ErrorPresenter.new(exception, Rails.env.test?, v3_hasher)
        YAML.dump(error_presenter.to_hash)
      end

      def save_error(api_error, job)
        PollableJobModel.where(delayed_job_guid: job.guid).update(cf_api_error: api_error)
      end

      def change_state(job, new_state)
        PollableJobModel.where(delayed_job_guid: job.guid).update(state: new_state)
      end
    end
  end
end
