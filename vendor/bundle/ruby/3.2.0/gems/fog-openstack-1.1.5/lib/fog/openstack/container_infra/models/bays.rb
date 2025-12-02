require 'fog/openstack/models/collection'
require 'fog/openstack/container_infra/models/bay'

module Fog
  module OpenStack
    class  ContainerInfra
      class Bays < Fog::OpenStack::Collection
        model Fog::OpenStack::ContainerInfra::Bay

        def all
          load_response(service.list_bays, "bays")
        end

        def get(bay_uuid_or_name)
          resource = service.get_bay(bay_uuid_or_name).body
          new(resource)
        rescue Fog::OpenStack::ContainerInfra::NotFound
          nil
        end
      end
    end
  end
end
