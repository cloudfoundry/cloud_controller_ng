module VCAP::CloudController::RoutingApi
  class RouterGroup
    attr_reader :guid, :type, :reservable_ports, :name
    def initialize(hash)
      @guid = hash['guid']
      @name = hash['name']
      @type = hash['type']
      @reservable_ports = hash['reservable_ports']
    end

    def ==(other)
      guid == other.guid
    end

    def reservable_ports
      ports = []
      port_ranges = @reservable_ports.split(',')

      port_ranges.each do |port_range|
        port_bounds = port_range.split('-')

        min = port_bounds[0].to_i
        max = port_bounds.length > 1 ? port_bounds[1].to_i : min

        (min..max).each do |port|
          ports.push(port)
        end
      end

      ports.sort.uniq
    end
  end
end
