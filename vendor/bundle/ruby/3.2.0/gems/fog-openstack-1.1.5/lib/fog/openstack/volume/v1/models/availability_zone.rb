require 'fog/openstack/volume/models/availability_zone'

module Fog
  module OpenStack
    class Volume
      class V1
        class AvailabilityZone < Fog::OpenStack::Volume::AvailabilityZone
          identity :zoneName

          attribute :zoneState
        end
      end
    end
  end
end
