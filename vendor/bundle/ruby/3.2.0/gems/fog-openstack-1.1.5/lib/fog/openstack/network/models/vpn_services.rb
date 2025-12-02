require 'fog/openstack/models/collection'
require 'fog/openstack/network/models/vpn_service'

module Fog
  module OpenStack
    class Network
      class VpnServices < Fog::OpenStack::Collection
        attribute :filters

        model Fog::OpenStack::Network::VpnService

        def initialize(attributes)
          self.filters ||= {}
          super
        end

        def all(filters_arg = filters)
          filters = filters_arg
          load_response(service.list_vpn_services(filters), 'vpnservices')
        end

        def get(vpn_service_id)
          if vpn_service = service.get_vpn_service(vpn_service_id).body['vpnservice']
            new(vpn_service)
          end
        rescue Fog::OpenStack::Network::NotFound
          nil
        end
      end
    end
  end
end
