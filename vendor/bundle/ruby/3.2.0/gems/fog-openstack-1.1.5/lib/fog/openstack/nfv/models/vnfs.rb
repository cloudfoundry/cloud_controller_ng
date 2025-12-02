require 'fog/openstack/models/collection'
require 'fog/openstack/nfv/models/vnf'

module Fog
  module OpenStack
    class NFV
      class Vnfs < Fog::OpenStack::Collection
        model Fog::OpenStack::NFV::Vnf

        def all(options = {})
          load_response(service.list_vnfs(options), 'vnfs')
        end

        def get(uuid)
          data = service.get_vnf(uuid).body['vnf']
          new(data)
        rescue Fog::OpenStack::NFV::NotFound
          nil
        end

        def destroy(uuid)
          vnf = get(uuid)
          vnf.destroy
        end
      end
    end
  end
end
