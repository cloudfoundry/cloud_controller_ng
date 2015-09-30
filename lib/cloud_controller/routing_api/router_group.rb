module VCAP::CloudController::RoutingApi
  class RouterGroup
    attr_reader :guid
    def initialize(hash)
      @guid = hash['guid']
    end

    def ==(other)
      guid == other.guid
    end
  end
end
