require 'fog/openstack/models/collection'
require 'fog/openstack/volume/v2/models/availability_zone'
require 'fog/openstack/volume/models/availability_zones'

module Fog
  module OpenStack
    class Volume
      class V2
        class AvailabilityZones < Fog::OpenStack::Collection
          model Fog::OpenStack::Volume::V2::AvailabilityZone
          include Fog::OpenStack::Volume::AvailabilityZones
        end
      end
    end
  end
end
