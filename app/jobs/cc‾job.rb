module VCAP::CloudController
  module Jobs
    class CCJob
      def reschedule_at(time, attempts)
        time + (attempts**4) + 5
      end
    end
  end
end
