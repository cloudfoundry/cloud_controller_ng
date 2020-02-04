module VCAP::CloudController
  module Jobs
    class DeleteActionJob < VCAP::CloudController::Jobs::CCJob
      NO_ERRORS = [].freeze

      attr_reader :resource_guid

      def initialize(model_class, resource_guid, delete_action, resource_type=nil)
        @model_class    = model_class
        @resource_guid  = resource_guid
        @delete_action  = delete_action
        @resource_type = resource_type || model_class.name.demodulize.gsub('Model', '').underscore
      end

      def perform
        logger = Steno.logger('cc.background')
        logger.info("Deleting model class '#{model_class}' with guid '#{resource_guid}'")

        dataset = model_class.where(guid: resource_guid)
        if delete_action_can_return_warnings?
          errors, warnings = delete_action.delete(dataset)
        else
          errors = delete_action.delete(dataset)
        end

        raise errors.first unless errors&.empty?

        warnings
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
        @resource_type
      end

      def display_name
        "#{resource_type}.delete"
      end

      private

      def delete_action_can_return_warnings?
        delete_action.respond_to?(:can_return_warnings?) && delete_action.can_return_warnings?
      end

      attr_reader :model_class, :delete_action
    end
  end
end
