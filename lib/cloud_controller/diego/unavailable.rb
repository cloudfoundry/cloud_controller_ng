module VCAP::CloudController
  module Diego
    class Unavailable < RuntimeError
      def initialize(exception = nil)
        @wrapped_exception = exception
      end

      def to_s
        message = "Diego runtime is unavailable."
        message << " Error: #{@wrapped_exception}" if @wrapped_exception
        message
      end
    end
  end
end
