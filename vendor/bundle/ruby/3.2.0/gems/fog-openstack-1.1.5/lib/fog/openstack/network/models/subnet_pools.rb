require 'fog/openstack/models/collection'
require 'fog/openstack/network/models/subnet_pool'

module Fog
  module OpenStack
    class Network
      class SubnetPools < Fog::OpenStack::Collection
        attribute :filters

        model Fog::OpenStack::Network::SubnetPool

        def initialize(attributes)
          self.filters ||= {}
          super
        end

        def all(filters_arg = filters)
          filters = filters_arg
          load_response(service.list_subnet_pools(filters), 'subnetpools')
        end

        def get(subnet_pool_id)
          subnet_pool = service.get_subnet_pool(subnet_pool_id).body['subnetpool']
          if subnet_pool
            new(subnet_pool)
          end
        rescue Fog::OpenStack::Network::NotFound
          nil
        end
      end
    end
  end
end
