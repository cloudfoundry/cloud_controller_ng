module CloudController
  module Errors
    class CompoundError < StandardError
      def initialize(errors)
        @errors = errors
      end

      def underlying_errors
        @errors
      end

      def response_code
        @errors.first.response_code
      end
    end
  end
end
