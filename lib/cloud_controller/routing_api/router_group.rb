module VCAP::CloudController::RoutingApi
  class RouterGroup
    attr_reader :guid, :type
    def initialize(hash)
      @guid = hash['guid']
      @type = hash['type']
    end

    def ==(other)
      guid == other.guid
    end
  end
end
