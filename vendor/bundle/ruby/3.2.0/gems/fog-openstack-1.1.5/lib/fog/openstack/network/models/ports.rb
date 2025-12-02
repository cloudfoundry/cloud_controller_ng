require 'fog/openstack/models/collection'
require 'fog/openstack/network/models/port'

module Fog
  module OpenStack
    class Network
      class Ports < Fog::OpenStack::Collection
        attribute :filters

        model Fog::OpenStack::Network::Port

        def initialize(attributes)
          self.filters ||= {}
          super
        end

        def all(filters_arg = filters)
          filters = filters_arg
          load_response(service.list_ports(filters), 'ports')
        end

        def get(port_id)
          if port = service.get_port(port_id).body['port']
            new(port)
          end
        rescue Fog::OpenStack::Network::NotFound
          nil
        end
      end
    end
  end
end
