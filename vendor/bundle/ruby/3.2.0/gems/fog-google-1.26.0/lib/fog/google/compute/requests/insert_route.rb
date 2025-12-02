module Fog
  module Google
    class Compute
      class Mock
        def insert_route(_route_name, _network, _dest_range, _priority, _options = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        # Creates a Route resource.
        #
        # @see https://cloud.google.com/compute/docs/reference/latest/routes/insert
        def insert_route(route_name, network, dest_range, priority, options = {})
          route = ::Google::Apis::ComputeV1::Route.new(
            name: route_name,
            network: network,
            dest_range: dest_range,
            priority: priority,
            tags: options[:tags] || [],
            next_hop_instance: options[:next_hop_instance],
            next_hop_gateway: options[:next_hop_gateway],
            next_hop_ip: options[:next_hop_ip],
            next_hop_vpn_tunnel: options[:next_hop_vpn_tunnel],
            description: options[:description]
          )

          @compute.insert_route(@project, route)
        end
      end
    end
  end
end
