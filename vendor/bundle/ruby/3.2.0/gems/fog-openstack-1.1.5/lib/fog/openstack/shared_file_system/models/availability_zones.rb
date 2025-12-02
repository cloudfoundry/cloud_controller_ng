require 'fog/openstack/models/collection'
require 'fog/openstack/shared_file_system/models/availability_zone'

module Fog
  module OpenStack
    class SharedFileSystem
      class AvailabilityZones < Fog::OpenStack::Collection
        model Fog::OpenStack::SharedFileSystem::AvailabilityZone

        def all
          load_response(service.list_availability_zones(), 'availability_zones')
        end
      end
    end
  end
end
