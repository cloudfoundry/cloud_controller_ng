require 'fog/openstack/models/collection'
require 'fog/openstack/network/models/network_ip_availability'

module Fog
  module OpenStack
    class Network
      class NetworkIpAvailabilities < Fog::OpenStack::Collection
        model Fog::OpenStack::Network::NetworkIpAvailability

        def all
          load_response(service.list_network_ip_availabilities, 'network_ip_availabilities')
        end

        def get(network_id)
          if network_ip_availability = service.get_network_ip_availability(network_id).body['network_ip_availability']
            new(network_ip_availability)
          end
        rescue Fog::OpenStack::Network::NotFound
          nil
        end
      end
    end
  end
end
