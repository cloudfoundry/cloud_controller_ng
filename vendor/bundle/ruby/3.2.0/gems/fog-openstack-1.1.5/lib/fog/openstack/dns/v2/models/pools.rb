require 'fog/openstack/models/collection'
require 'fog/openstack/dns/v2/models/pool'

module Fog
  module OpenStack
    class DNS
      class V2
        class Pools < Fog::OpenStack::Collection
          model Fog::OpenStack::DNS::V2::Pool

          def all(options = {})
            load_response(service.list_pools(options), 'pools')
          end

          def find_by_id(id, options = {})
            pool_hash = service.get_pool(id, options).body
            new(pool_hash.merge(:service => service))
          end

          alias get find_by_id
        end
      end
    end
  end
end
