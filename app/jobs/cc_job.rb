module VCAP::CloudController
  module Jobs
    class CCJob
      def before(delayed_job)
        GenericEnqueuer.shared(priority: delayed_job.priority)
      end

      def after(_delayed_job)
        GenericEnqueuer.reset!
      end

      def reschedule_at(time, attempts)
        time + (attempts**4) + 5
      end
    end
  end
end
