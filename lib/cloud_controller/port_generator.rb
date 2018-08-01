module VCAP::CloudController
  class PortGenerator
    def initialize(domain_guid)
      @domain_guid = domain_guid
    end

    def generate_port(possible_ports)
      router_group_guid = get_router_group_guid(@domain_guid)

      unavailable_ports = Route.join(:domains, id: :domain_id).
                          where(router_group_guid: router_group_guid).
                          select_map(:port)

      available_ports = possible_ports - unavailable_ports

      size = available_ports.size

      if size == 0
        return -1
      end

      row_index = Random.new.rand(size)

      available_ports[row_index]
    end

    def get_router_group_guid(domain_guid)
      SharedDomain.where(guid: domain_guid).
        select(:router_group_guid).
        first.router_group_guid
    end
  end
end
