require 'fog/openstack/models/collection'
require 'fog/openstack/network/models/router'

module Fog
  module OpenStack
    class Network
      class Routers < Fog::OpenStack::Collection
        attribute :filters

        model Fog::OpenStack::Network::Router

        def initialize(attributes)
          self.filters ||= {}
          super
        end

        def all(filters_arg = filters)
          filters = filters_arg
          load_response(service.list_routers(filters), 'routers')
        end

        def get(router_id)
          if router = service.get_router(router_id).body['router']
            new(router)
          end
        rescue Fog::OpenStack::Network::NotFound
          nil
        end
      end
    end
  end
end
