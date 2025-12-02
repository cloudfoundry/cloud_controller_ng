require 'fog/openstack/volume/models/volume'

module Fog
  module OpenStack
    class Volume
      class V2
        class Volume < Fog::OpenStack::Volume::Volume
          identity :id

          superclass.attributes.each { |attrib| attribute attrib }
          attribute :name
          attribute :description
          attribute :tenant_id, :aliases => 'os-vol-tenant-attr:tenant_id'

          def save
            requires :name, :size
            data = if id.nil?
                     service.create_volume(name, description, size, attributes)
                   else
                     service.update_volume(id, attributes.select { |key| %i(name description metadata).include?(key) })
                   end
            merge_attributes(data.body['volume'])
            true
          end

          def update(attr = nil)
            requires :id
            merge_attributes(
              service.update_volume(id, attr || attributes).body['volume']
            )
            self
          end
        end
      end
    end
  end
end
