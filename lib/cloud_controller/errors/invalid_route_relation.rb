module VCAP::CloudController
  module Errors
    class InvalidRouteRelation < InvalidRelation
      def to_s
        "The URL was not available [route ID #{super}]"
      end
    end
  end
end
