module VCAP::CloudController
  module Jobs
    class Enqueuer
      def initialize(job, opts={})
        @job = job
        @opts = opts
      end

      def enqueue
        request_id = ::VCAP::Request.current_id
        Delayed::Job.enqueue(ExceptionCatchingJob.new(RequestJob.new(TimeoutJob.new(@job), request_id)), @opts)
      end
    end
  end
end
