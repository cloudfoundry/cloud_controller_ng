module VCAP::CloudController
  module Jobs
    class DeleteActionJob < VCAP::CloudController::Jobs::CCJob
      def initialize(fetcher, delete_action)
        @fetcher = fetcher
        @delete_action = delete_action
      end

      def perform
        dataset = @fetcher.fetch
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
