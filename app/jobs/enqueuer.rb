require "jobs/timeout_job"

module VCAP::CloudController
  module Jobs
    class Enqueuer < Struct.new(:job, :opts)
      def enqueue
        Delayed::Job.enqueue(TimeoutJob.new(job), opts)
      end
    end
  end
end