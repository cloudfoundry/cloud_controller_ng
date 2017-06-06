module VCAP::CloudController
  module Jobs
    class DeleteActionJob < VCAP::CloudController::Jobs::CCJob
      def initialize(model_class, guid, delete_action, resource_type=nil, operation_name=nil)
        @model_class    = model_class
        @guid           = guid
        @delete_action  = delete_action
        @resource_type  = resource_type
        @operation_name = operation_name
      end

      def perform
        logger = Steno.logger('cc.background')
        logger.info("Deleting model class '#{model_class}' with guid '#{guid}'")

        dataset = model_class.where(guid: guid)
        errors  = delete_action.delete(dataset)
        raise errors.first unless errors.empty?
      end

      def job_name_in_configuration
        :delete_action_job
      end

      def max_attempts
        1
      end

      def timeout_error
        if delete_action.respond_to?(:timeout_error)
          dataset = model_class.where(guid: guid)
          delete_action.timeout_error(dataset)
        else
          CloudController::Errors::ApiError.new_from_details('JobTimeout')
        end
      end

      def success(job)
        HistoricalJobModel.where(guid: job.guid).update(state: HistoricalJobModel::COMPLETE_STATE)
      end

      def failure(job)
        HistoricalJobModel.where(guid: job.guid).update(state: HistoricalJobModel::FAILED_STATE)
      end

      def before(job)
        HistoricalJobModel.create(
          guid:          job.guid,
          operation:     operation_name,
          state:         HistoricalJobModel::PROCESSING_STATE,
          resource_guid: guid,
          resource_type: resource_type,
        )
      end

      private

      attr_reader :model_class, :guid, :delete_action, :resource_type, :operation_name
    end
  end
end
