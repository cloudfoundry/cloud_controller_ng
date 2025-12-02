require 'fog/openstack/models/collection'
require 'fog/openstack/network/models/network'

module Fog
  module OpenStack
    class Network
      class Networks < Fog::OpenStack::Collection
        attribute :filters

        model Fog::OpenStack::Network::Network

        def initialize(attributes)
          self.filters ||= {}
          super
        end

        def all(filters_arg = filters)
          filters = filters_arg
          load_response(service.list_networks(filters), 'networks')
        end

        def get(network_id)
          if network = service.get_network(network_id).body['network']
            new(network)
          end
        rescue Fog::OpenStack::Network::NotFound
          nil
        end
      end
    end
  end
end
