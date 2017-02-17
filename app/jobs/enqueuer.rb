require 'clockwork'

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

      def run_inline
        run_immediately do
          Delayed::Job.enqueue(@job, @opts)
        end
      end

      private

      def run_immediately
        cache = Delayed::Worker.delay_jobs
        Delayed::Worker.delay_jobs = false
        yield
      ensure
        Delayed::Worker.delay_jobs = cache
      end
    end
  end
end
