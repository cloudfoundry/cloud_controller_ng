require 'fog/openstack/models/collection'
require 'fog/openstack/compute/models/server_group'

module Fog
  module OpenStack
    class Compute
      class ServerGroups < Fog::OpenStack::Collection
        model Fog::OpenStack::Compute::ServerGroup

        def all(options = {})
          load_response(service.list_server_groups(options), 'server_groups')
        end

        def get(server_group_id)
          if server_group_id
            new(service.get_server_group(server_group_id).body['server_group'])
          end
        rescue Fog::OpenStack::Compute::NotFound
          nil
        end

        def create(*args)
          new(service.create_server_group(*args).body['server_group'])
        end
      end
    end
  end
end
