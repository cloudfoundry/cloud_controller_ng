require 'fog/openstack/volume/models/backup'

module Fog
  module OpenStack
    class Volume
      class V2
        class Backup < Fog::OpenStack::Volume::Backup
          identity :id

          superclass.attributes.each { |attrib| attribute attrib }
        end
      end
    end
  end
end
