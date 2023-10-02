module VCAP::CloudController
  class PortGenerator
    class << self
      def generate_port(domain_guid, possible_ports)
        domain = SharedDomain.where(guid: domain_guid).first
        router_group_guid = domain.router_group_guid

        unavailable_ports = Route.join(:domains, id: :domain_id).
                            where(router_group_guid:).
                            select_map(:port)

        available_ports = possible_ports - unavailable_ports

        size = available_ports.size

        return -1 if size == 0

        row_index = Random.new.rand(size)

        available_ports[row_index]
      end
    end
  end
end
