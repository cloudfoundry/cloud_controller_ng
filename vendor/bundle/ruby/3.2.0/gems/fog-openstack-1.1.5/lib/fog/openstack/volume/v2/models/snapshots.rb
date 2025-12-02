require 'fog/openstack/models/collection'
require 'fog/openstack/volume/v2/models/snapshot'
require 'fog/openstack/volume/models/snapshots'

module Fog
  module OpenStack
    class Volume
      class V2
        class Snapshots < Fog::OpenStack::Collection
          model Fog::OpenStack::Volume::V2::Snapshot
          include Fog::OpenStack::Volume::Snapshots
        end
      end
    end
  end
end
