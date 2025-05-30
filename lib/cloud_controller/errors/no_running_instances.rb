module CloudController
  module Errors
    class NoRunningInstances < RuntimeError
      def initialize(wrapped_exception)
        @wrapped_exception = wrapped_exception
      end

      delegate :to_s, to: :@wrapped_exception
    end
  end
end
