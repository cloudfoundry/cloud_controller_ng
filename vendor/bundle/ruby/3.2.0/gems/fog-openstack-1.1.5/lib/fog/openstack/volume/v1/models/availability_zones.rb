require 'fog/openstack/models/collection'
require 'fog/openstack/volume/v1/models/availability_zone'
require 'fog/openstack/volume/models/availability_zones'

module Fog
  module OpenStack
    class Volume
      class V1
        class AvailabilityZones < Fog::OpenStack::Collection
          model Fog::OpenStack::Volume::V1::AvailabilityZone
          include Fog::OpenStack::Volume::AvailabilityZones
        end
      end
    end
  end
end
