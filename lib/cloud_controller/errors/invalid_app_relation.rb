module CloudController
  module Errors
    class InvalidAppRelation < InvalidRelation
      def to_s
        "The requested app relation is invalid: #{super}"
      end
    end
  end
end
