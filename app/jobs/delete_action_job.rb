module VCAP::CloudController
  module Jobs
    class DeleteActionJob < VCAP::CloudController::Jobs::CCJob
      def initialize(model_class, guid, delete_action)
        @model_class = model_class
        @guid = guid
        @delete_action = delete_action
      end

      def perform
        dataset = @model_class.where(guid: @guid)
        errors = @delete_action.delete(dataset)
        unless errors.empty?
          error = errors.first
          raise error.underlying_error
        end
      end

      def job_name_in_configuration
        :delete_action_job
      end

      def max_attempts
        1
      end
    end
  end
end
