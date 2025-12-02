require 'fog/openstack/models/collection'
require 'fog/openstack/volume/v2/models/backup'
require 'fog/openstack/volume/models/backups'

module Fog
  module OpenStack
    class Volume
      class V2
        class Backups < Fog::OpenStack::Collection
          model Fog::OpenStack::Volume::V2::Backup
          include Fog::OpenStack::Volume::Backups
        end
      end
    end
  end
end
