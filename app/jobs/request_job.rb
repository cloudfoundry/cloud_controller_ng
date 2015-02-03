module VCAP::CloudController
  module Jobs
    class RequestJob < WrappingJob
      def initialize(handler, request_id)
        @handler = handler
        @request_id = request_id
      end

      def perform
        current_request_id = ::VCAP::Request.current_id
        begin
          ::VCAP::Request.current_id = @request_id
          @handler.perform
        ensure
          ::VCAP::Request.current_id = current_request_id
        end
      end

      # TODO: fix bad tests that grab this
      def job
        @handler
      end

      # TODO: fix bad tests that grab this
      def request_id
        @request_id
      end
    end
  end
end
