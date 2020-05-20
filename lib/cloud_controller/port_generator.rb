module VCAP::CloudController
  class PortGenerator
    class << self
      def generate_port(domain_guid, possible_ports=nil)
        domain = SharedDomain.where(guid: domain_guid).first
        router_group_guid = domain.router_group_guid

        unavailable_ports = Route.join(:domains, id: :domain_id).
                            where(router_group_guid: router_group_guid).
                            select_map(:port)

        possible_ports ||= domain.router_group.reservable_ports
        available_ports = possible_ports - unavailable_ports

        size = available_ports.size

        if size == 0
          return -1
        end

        row_index = Random.new.rand(size)

        available_ports[row_index]
      end
    end
  end
end
