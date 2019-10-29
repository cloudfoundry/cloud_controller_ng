require 'presenters/error_presenter'
require 'utils/yaml_utils'

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
        # debugger
        api_error = convert_to_v3_api_error(exception)
        save_error(api_error, job)
      end

      def failure(job)
        change_state(job, PollableJobModel::FAILED_STATE)
      end

      def after(job)
        persist_warnings(job)
      end

      private

      def convert_to_v3_api_error(exception)
        v3_hasher = V3ErrorHasher.new(exception)
        error_presenter = ErrorPresenter.new(exception, Rails.env.test?, v3_hasher)
        res = YAML.dump(error_presenter.to_hash)
        # warn("QQQ: convert_to_v3_api_error:<<\n#{res[0..400]}...>>")
        res
      rescue Exception => ex
        warn("QQQ: convert_to_v3_api_error error => #{ex.message}\n traceback: #{ex.backtrace}")
        raise
      end

      def find_pollable_job(job)
        PollableJobModel.where(delayed_job_guid: job.guid)
      end

      def persist_warnings(job)
        if handler.respond_to?(:warnings)
          handler.warnings&.each do |warning|
            find_pollable_job(job).each do |pollable_job|
              JobWarningModel.create(job: pollable_job, detail: warning[:detail])
            end
          end
        end
      end

      # Need to update each pollable job instance individually to ensure timestamps are set correctly
      # Doing `ModelClass.where(CONDITION).update(field: value)` bypasses the sequel timestamp updater hook

      def save_error(api_error, job)
        # warn("QQQ: save_error: job: #{job.guid}")
        find_pollable_job(job).each do |pollable_job|
          # warn("QQQ: save_error: found pollable_job: guid: #{pollable_job.guid}, delayed_job_guid:#{pollable_job.delayed_job_guid}")
          pollable_job.update(cf_api_error: YamlUtils.truncate(api_error, 160_000))
          # warn("QQQ: PollableJobWrapper#save_error: saving cf_api_error <<\n#{api_error[0..500]}...>> from delayed-job #{job.guid} to pollable job #{pollable_job.guid}")
        rescue Exception => ex
          warn("error in PollableJobWrapper.save_error: #{ex.class}, #{ex.message}")
          raise
        end
      end

      def change_state(job, new_state)
        find_pollable_job(job).each do |pollable_job|
          pollable_job.update(state: new_state)
        end
      end
    end
  end
end
