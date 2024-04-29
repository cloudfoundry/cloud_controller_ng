module VCAP::CloudController
  module Jobs
    class CCJob
      attr_accessor :otel_tracing_carrier

      def reschedule_at(time, attempts)
        time + (attempts**4) + 5
      end
    end
  end
end
