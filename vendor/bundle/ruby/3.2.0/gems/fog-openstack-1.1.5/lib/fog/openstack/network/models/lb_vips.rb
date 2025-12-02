require 'fog/openstack/models/collection'
require 'fog/openstack/network/models/lb_vip'

module Fog
  module OpenStack
    class Network
      class LbVips < Fog::OpenStack::Collection
        attribute :filters

        model Fog::OpenStack::Network::LbVip

        def initialize(attributes)
          self.filters ||= {}
          super
        end

        def all(filters_arg = filters)
          filters = filters_arg
          load_response(service.list_lb_vips(filters), 'vips')
        end

        def get(vip_id)
          if vip = service.get_lb_vip(vip_id).body['vip']
            new(vip)
          end
        rescue Fog::OpenStack::Network::NotFound
          nil
        end
      end
    end
  end
end
