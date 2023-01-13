require 'presenters/error_presenter'
require 'jobs/wrapping_job'
require 'presenters/v3_error_hasher'

module VCAP::CloudController
  module Jobs
    class PollableJobWrapper < WrappingJob
      attr_reader :existing_guid

      def initialize(handler, existing_guid: nil)
        @existing_guid = existing_guid
        super(handler)
      end

      # use custom hook as Job does not have the guid field populated during the normal `enqueue` hook
      def before_enqueue(job)
        if existing_guid && (existing = PollableJobModel.find(guid: existing_guid))
          state = @handler.try(:pollable_job_state) || PollableJobModel::POLLING_STATE
          existing.update(
            delayed_job_guid: job.guid,
            state: state,
            operation: @handler.display_name,
            resource_guid: @handler.resource_guid,
            resource_type: @handler.resource_type
          )
        else
          PollableJobModel.create(
            delayed_job_guid: job.guid,
            state: PollableJobModel::PROCESSING_STATE,
            operation: @handler.display_name,
            resource_guid: @handler.resource_guid,
            resource_type: @handler.resource_type
          )
        end
      end

      def success(job)
        if @handler.respond_to?(:success)
          persist_warnings(job)
          @handler.success(job)
        else
          change_state(job, PollableJobModel::COMPLETE_STATE)
        end
      end

      def error(job, exception)
        begin
          api_error = convert_to_v3_api_error(exception)
          save_error(api_error, job)
        rescue Sequel::DatabaseError
          if (exception.backtrace.size rescue 0) > 0
            exception.backtrace.slice!((exception.backtrace.size / 2)..-1)
            retry
          else
            raise
          end
        end
      rescue StandardError => ex
        logger.error("can't yaml-encode exception #{exception}: #{ex.message}")
        raise
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
        find_pollable_job(job).each do |pollable_job|
          pollable_job.update(cf_api_error: api_error)
        end
      end

      def change_state(job, new_state)
        persist_warnings(job)
        find_pollable_job(job).each do |pollable_job|
          pollable_job.update(state: new_state)
        end
      end

      def logger
        @logger ||= Steno.logger('cc.pollable.job.wrapper')
      end
    end
  end
end
