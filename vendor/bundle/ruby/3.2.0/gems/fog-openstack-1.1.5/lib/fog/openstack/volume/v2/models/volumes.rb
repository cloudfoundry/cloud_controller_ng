require 'fog/openstack/models/collection'
require 'fog/openstack/volume/v2/models/volume'
require 'fog/openstack/volume/models/volumes'

module Fog
  module OpenStack
    class Volume
      class V2
        class Volumes < Fog::OpenStack::Collection
          model Fog::OpenStack::Volume::V2::Volume
          include Fog::OpenStack::Volume::Volumes
        end
      end
    end
  end
end
