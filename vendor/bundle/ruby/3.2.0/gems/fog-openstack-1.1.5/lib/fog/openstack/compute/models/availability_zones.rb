require 'fog/openstack/models/collection'
require 'fog/openstack/compute/models/availability_zone'

module Fog
  module OpenStack
    class Compute
      class AvailabilityZones < Fog::OpenStack::Collection
        model Fog::OpenStack::Compute::AvailabilityZone

        def all(options = {})
          data = service.list_zones_detailed(options)
          load_response(data, 'availabilityZoneInfo')
        end

        def summary(options = {})
          data = service.list_zones(options)
          load_response(data, 'availabilityZoneInfo')
        end
      end
    end
  end
end
