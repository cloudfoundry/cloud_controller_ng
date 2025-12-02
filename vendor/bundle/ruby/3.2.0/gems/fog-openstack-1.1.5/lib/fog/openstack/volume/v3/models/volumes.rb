require 'fog/openstack/models/collection'
require 'fog/openstack/volume/v3/models/volume'
require 'fog/openstack/volume/models/volumes'

module Fog
  module OpenStack
    class Volume
      class V3
        class Volumes < Fog::OpenStack::Collection
          model Fog::OpenStack::Volume::V3::Volume
          include Fog::OpenStack::Volume::Volumes
        end
      end
    end
  end
end
