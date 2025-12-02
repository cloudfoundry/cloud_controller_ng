require 'fog/openstack/models/collection'
require 'fog/openstack/shared_file_system/models/share_access_rule'

module Fog
  module OpenStack
    class SharedFileSystem
      class ShareExportLocations < Fog::OpenStack::Collection
        model Fog::OpenStack::SharedFileSystem::ShareExportLocation

        attr_accessor :share

        def all
          requires :share
          load_response(service.list_share_export_locations(@share.id), 'export_locations')
        end

        def find_by_id(id)
          location_hash = service.get_share_export_location(@share.id,id).body['export_location']
          new(location_hash.merge(:service => service))
        end

        alias get find_by_id

        def new(attributes = {})
          requires :share
          super({:share => @share}.merge!(attributes))
        end
      end
    end
  end
end
