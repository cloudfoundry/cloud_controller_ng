require 'fog/openstack/models/model'

module Fog
  module OpenStack
    class Compute
      class AvailabilityZone < Fog::OpenStack::Model
        identity :zoneName

        attribute :hosts
        attribute :zoneLabel
        attribute :zoneState

        def to_s
          zoneName
        end
      end
    end
  end
end
