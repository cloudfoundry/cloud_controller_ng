module VCAP::CloudController
  module Errors
    class InvalidRouteRelation < InvalidRelation
      def to_s
        "The requested route relation is invalid: #{super}"
      end
    end
  end
end
