require 'fog/openstack/models/collection'
require 'fog/openstack/compute/models/host'

module Fog
  module OpenStack
    class Compute
      class Hosts < Fog::OpenStack::Collection
        model Fog::OpenStack::Compute::Host

        def all(options = {})
          data = service.list_hosts(options)
          load_response(data, 'hosts')
        end

        def get(host_name)
          if host = service.get_host_details(host_name).body['host']
            new('host_name' => host_name,
                'details'   => host)
          end
        rescue Fog::OpenStack::Compute::NotFound
          nil
        end
      end
    end
  end
end
