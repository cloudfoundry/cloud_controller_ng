module VCAP::CloudController
  module Jobs
    class RequestJob < Struct.new(:job, :request_id)

      def perform
        current_request_id = ::VCAP::Request.current_id
        begin
          ::VCAP::Request.current_id = request_id
          job.perform
        ensure
          ::VCAP::Request.current_id = current_request_id
        end
      end
    end
  end
end