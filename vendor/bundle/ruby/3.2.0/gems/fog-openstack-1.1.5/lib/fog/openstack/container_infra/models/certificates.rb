require 'fog/openstack/models/collection'
require 'fog/openstack/container_infra/models/certificate'

module Fog
  module OpenStack
    class  ContainerInfra
      class Certificates < Fog::OpenStack::Collection

        model Fog::OpenStack::ContainerInfra::Certificate

        def create(bay_uuid)
          resource = service.create_certificate(bay_uuid).body
          new(resource)
        end

        def get(bay_uuid)
          resource = service.get_certificate(bay_uuid).body
          new(resource)
        rescue Fog::OpenStack::ContainerInfra::NotFound
          nil
        end
      end
    end
  end
end
