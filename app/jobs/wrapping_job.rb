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
        @handler.respond_to?(:max_attempts) ? @handler.max_attempts : 1
      end

      def reschedule_at(time, attempts)
        @handler.reschedule_at(time, attempts) if @handler.respond_to?(:reschedule_at)
      end

      def error(job, e)
        @handler.error(job, e) if @handler.respond_to?(:error)
      end

      def handler
        @handler
      end
    end
  end
end
