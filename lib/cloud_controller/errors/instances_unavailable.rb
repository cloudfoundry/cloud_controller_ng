module VCAP::CloudController
  module Errors
    class InstancesUnavailable < RuntimeError
      def initialize(wrapped_exception)
        @wrapped_exception = wrapped_exception
      end

      def to_s
        @wrapped_exception.to_s
      end
    end
  end
end
