module VCAP::CloudController
  module Jobs
    class DeleteActionJob < VCAP::CloudController::Jobs::CCJob
      def initialize(delete_action)
        @delete_action = delete_action
      end

      def perform
        @delete_action.delete
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
