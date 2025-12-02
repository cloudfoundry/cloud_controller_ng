require 'fog/openstack/models/collection'
require 'fog/openstack/nfv/models/vnfd'

module Fog
  module OpenStack
    class NFV
      class Vnfds < Fog::OpenStack::Collection
        model Fog::OpenStack::NFV::Vnfd

        def all(options = {})
          load_response(service.list_vnfds(options), 'vnfds')
        end

        def get(uuid)
          data = service.get_vnfd(uuid).body['vnfd']
          new(data)
        rescue Fog::OpenStack::NFV::NotFound
          nil
        end

        def destroy(uuid)
          vnfd = get(uuid)
          vnfd.destroy
        end
      end
    end
  end
end
