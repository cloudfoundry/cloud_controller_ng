module VCAP::CloudController
  module Jobs
    class WrappingJob < VCAP::CloudController::Jobs::CCJob
      attr_reader :handler

      def initialize(handler)
        @handler = handler
      end

      def perform
        handler.perform
      end

      def after_enqueue(job)
        handler.after_enqueue(job) if handler.respond_to?(:after_enqueue)
      end

      def before(job)
        handler.before(job) if handler.respond_to?(:before)
      end

      def success(job)
        handler.success(job) if handler.respond_to?(:success)
      end

      def failure(job)
        handler.failure(job) if handler.respond_to?(:failure)
      end

      def max_attempts
        handler.respond_to?(:max_attempts) ? handler.max_attempts : 1
      end

      def reschedule_at(time, attempts)
        handler.reschedule_at(time, attempts) if handler.respond_to?(:reschedule_at)
      end

      def error(job, e)
        handler.error(job, e) if handler.respond_to?(:error)
      end

      def display_name
        handler.respond_to?(:display_name) ? handler.display_name : handler.class.name
      end

      def wrapped_handler
        handler.respond_to?(:wrapped_handler) ? handler.wrapped_handler : handler
      end

      def resource_type
        handler.respond_to?(:resource_type) ? handler.resource_type : nil
      end

      def resource_guid
        handler.respond_to?(:resource_guid) ? handler.resource_guid : nil
      end
    end
  end
end
