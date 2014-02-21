require "jobs/timeout_job"

module VCAP::CloudController
  module Jobs
    class Enqueuer
      def initialize(job, opts = {})
        @job = job
        @opts = opts
      end
      def enqueue
        Delayed::Job.enqueue(ExceptionCatchingJob.new(TimeoutJob.new(@job)), @opts)
      end
    end
  end
end