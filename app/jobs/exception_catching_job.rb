module VCAP::CloudController
  module Jobs
    class ExceptionCatchingJob < Struct.new(:handler)
      def perform
        handler.perform
      end

      def error(job, e)
        job.cf_api_error = ExceptionMarshaler.marshal(e)
        job.save
      end
    end
  end
end