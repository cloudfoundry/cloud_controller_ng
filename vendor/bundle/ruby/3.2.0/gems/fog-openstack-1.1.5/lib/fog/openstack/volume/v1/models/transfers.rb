require 'fog/openstack/models/collection'
require 'fog/openstack/volume/v1/models/transfer'
require 'fog/openstack/volume/models/transfers'

module Fog
  module OpenStack
    class Volume
      class V1
        class Transfers < Fog::OpenStack::Collection
          model Fog::OpenStack::Volume::V1::Transfer
          include Fog::OpenStack::Volume::Transfers
        end
      end
    end
  end
end
