require 'fog/openstack/volume/models/volume_type'

module Fog
  module OpenStack
    class Volume
      class V1
        class VolumeType < Fog::OpenStack::Volume::VolumeType
          identity :id

          attribute :name
          attribute :volume_backend_name
        end
      end
    end
  end
end
