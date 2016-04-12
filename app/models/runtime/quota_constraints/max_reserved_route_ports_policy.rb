class MaxReservedRoutePortsPolicy
  def initialize(quota_defintion, port_counter)
    @quota_definition = quota_defintion
    @port_counter = port_counter
  end

  def allow_more_route_ports?
    reservable_ports = @quota_definition.total_reserved_route_ports

    return true if reservable_ports == -1
    return false if @port_counter.count >= reservable_ports

    true
  end
end
