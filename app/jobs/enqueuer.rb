module VCAP::CloudController
  module Jobs
    class Enqueuer < Struct.new(:job, :opts)
      def enqueue
        Delayed::Job.enqueue(job, opts)
      end
    end
  end
end