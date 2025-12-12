module VCAP::CloudController
  module Jobs
    class InlineRunner < Enqueuer
      class << self
        def setup
          Delayed::Worker.delay_jobs = lambda do |job|
            unwrapped_job = unwrap_job(job.payload_object)
            !(unwrapped_job.respond_to?(:inline?) && unwrapped_job.inline?)
          end
        end
      end

      def run(job)
        raise ArgumentError.new("job must define a method 'inline?' which returns 'true'") unless job.respond_to?(:inline?) && job.inline?

        Delayed::Job.enqueue(TimeoutJob.new(job, job_timeout(job)), @opts)
      end
    end
  end
end
