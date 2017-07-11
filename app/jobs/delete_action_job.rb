module VCAP::CloudController
  module Jobs
    class DeleteActionJob < VCAP::CloudController::Jobs::CCJob
      attr_reader :resource_guid

      def initialize(model_class, resource_guid, delete_action)
        @model_class    = model_class
        @resource_guid  = resource_guid
        @delete_action  = delete_action
      end

      def perform
        logger = Steno.logger('cc.background')
        logger.info("Deleting model class '#{model_class}' with guid '#{resource_guid}'")

        dataset = model_class.where(guid: resource_guid)
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
          dataset = model_class.where(guid: resource_guid)
          delete_action.timeout_error(dataset)
        else
          CloudController::Errors::ApiError.new_from_details('JobTimeout')
        end
      end

      def resource_type
        @model_class.name.demodulize.gsub('Model', '').underscore
      end

      def display_name
        "#{resource_type}.delete"
      end

      private

      attr_reader :model_class, :delete_action
    end
  end
end
