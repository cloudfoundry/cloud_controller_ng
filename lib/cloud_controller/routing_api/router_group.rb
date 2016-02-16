module VCAP::CloudController::RoutingApi
  class RouterGroup
    attr_reader :guid, :types
    def initialize(hash)
      @guid = hash['guid']
      @types = []
      @types.push(hash['type'])
    end

    def ==(other)
      guid == other.guid
    end
  end
end
