require 'fog/openstack/models/collection'
require 'fog/openstack/volume/v2/models/volume_type'
require 'fog/openstack/volume/models/volume_types'

module Fog
  module OpenStack
    class Volume
      class V2
        class VolumeTypes < Fog::OpenStack::Collection
          model Fog::OpenStack::Volume::V2::VolumeType
          include Fog::OpenStack::Volume::VolumeTypes
        end
      end
    end
  end
end
