require 'fog/openstack/models/collection'
require 'fog/openstack/volume/v2/models/transfer'
require 'fog/openstack/volume/models/transfers'

module Fog
  module OpenStack
    class Volume
      class V2
        class Transfers < Fog::OpenStack::Collection
          model Fog::OpenStack::Volume::V2::Transfer
          include Fog::OpenStack::Volume::Transfers
        end
      end
    end
  end
end
