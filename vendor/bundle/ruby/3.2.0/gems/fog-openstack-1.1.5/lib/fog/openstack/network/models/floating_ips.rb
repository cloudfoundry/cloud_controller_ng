require 'fog/openstack/models/collection'
require 'fog/openstack/network/models/floating_ip'

module Fog
  module OpenStack
    class Network
      class FloatingIps < Fog::OpenStack::Collection
        attribute :filters

        model Fog::OpenStack::Network::FloatingIp

        def initialize(attributes)
          self.filters ||= {}
          super
        end

        def all(filters_arg = filters)
          filters = filters_arg
          load_response(service.list_floating_ips(filters), 'floatingips')
        end

        def get(floating_network_id)
          if floating_ip = service.get_floating_ip(floating_network_id).body['floatingip']
            new(floating_ip)
          end
        rescue Fog::OpenStack::Network::NotFound
          nil
        end
      end
    end
  end
end
