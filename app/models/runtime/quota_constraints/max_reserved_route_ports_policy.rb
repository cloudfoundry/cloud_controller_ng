module VCAP::CloudController
  class MaxReservedRoutePortsPolicy
    def initialize(quota_defintion, port_counter)
      @quota_definition = quota_defintion
      @port_counter = port_counter
    end

    def allow_more_route_ports?
      reservable_ports = @quota_definition.total_reserved_route_ports
      number_of_existing_ports = @port_counter.count
      total_routes = @quota_definition.total_routes

      if reservable_ports == VCAP::CloudController::QuotaDefinition::UNLIMITED
        return false if total_routes <= number_of_existing_ports && total_routes != VCAP::CloudController::QuotaDefinition::UNLIMITED
        return true
      end

      return false if number_of_existing_ports >= reservable_ports

      true
    end
  end
end
