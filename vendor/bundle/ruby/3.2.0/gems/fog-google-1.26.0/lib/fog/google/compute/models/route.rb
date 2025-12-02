module Fog
  module Google
    class Compute
      ##
      # Represents a Route resource
      #
      # @see https://developers.google.com/compute/docs/reference/latest/routes
      class Route < Fog::Model
        identity :name

        attribute :kind
        attribute :id
        attribute :creation_timestamp, :aliases => "creationTimestamp"
        attribute :description
        attribute :dest_range, :aliases => "destRange"
        attribute :network
        attribute :next_hop_gateway, :aliases => "nextHopGateway"
        attribute :next_hop_instance, :aliases => "nextHopInstance"
        attribute :next_hop_ip, :aliases => "nextHopIp"
        attribute :next_hop_network, :aliases => "nextHopNetwork"
        attribute :next_hop_vpn_tunnel, :aliases => "nextHopVpnTunnel"
        attribute :priority
        attribute :self_link, :aliases => "selfLink"
        attribute :tags
        attribute :warnings

        def save
          requires :identity, :network, :dest_range, :priority

          data = service.insert_route(identity, network, dest_range, priority, attributes)
          operation = Fog::Google::Compute::Operations.new(:service => service)
                                                      .get(data.name)
          operation.wait_for { ready? }
          reload
        end

        def destroy(async = true)
          requires :identity

          data = service.delete_route(identity)
          operation = Fog::Google::Compute::Operations.new(:service => service)
                                                      .get(data.name)
          operation.wait_for { ready? } unless async
          operation
        end
      end
    end
  end
end
