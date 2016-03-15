module VCAP::CloudController::RoutingApi
  class RouterGroup
    attr_reader :guid, :types, :reservable_ports
    def initialize(hash)
      @guid = hash['guid']
      @types = []
      @types.push(hash['type'])
      @reservable_ports = hash['reservable_ports']
    end

    def ==(other)
      guid == other.guid
    end

    def reservable_ports
      ports = []
      portRanges = @reservable_ports.split(",")

      portRanges.each do |portRange|
        portBounds = portRange.split("-")

        min = portBounds[0].to_i
        max = portBounds.length > 1 ? portBounds[1].to_i : min
        for i in  min .. max
          ports.push(i)
        end

      end

      ports.sort().uniq()
    end
  end
end
