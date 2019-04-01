module CloudController
  module Errors
    class NotAuthenticated < RuntimeError
      def name
        'NotAuthenticated'
      end

      def response_code
        401
      end

      def message
        'Authentication error'
      end

      def code
        10002
      end
      alias_method :error_code, :code
    end
  end
end
