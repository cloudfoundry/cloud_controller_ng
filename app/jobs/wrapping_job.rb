module VCAP::CloudController
  module Jobs
    class WrappingJob < VCAP::CloudController::Jobs::CCJob
      def initialize(handler)
        @handler = handler
      end

      def perform
        @handler.perform
      end

      def max_attempts
        @handler.max_attempts
      end

      def reschedule_at(time, attempts)
        @handler.reschedule_at(time, attempts)
      end

      def error(job, e)
        @handler.error(job, e)
      end

      # TODO: fix bad tests that poke at this
      def handler
        @handler
      end
    end
  end
end
