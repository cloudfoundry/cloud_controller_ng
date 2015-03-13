module VCAP::CloudController
  module Jobs
    class DeleteActionJob < VCAP::CloudController::Jobs::CCJob
      def initialize(fetcher, delete_action)
        @fetcher = fetcher
        @delete_action = delete_action
      end

      def perform
        dataset = @fetcher.fetch
        @delete_action.delete(dataset)
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
