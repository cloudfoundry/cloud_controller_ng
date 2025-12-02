require 'fog/core/collection'

module Fog
  module OpenStack
    class Compute
      class VolumeAttachments < Fog::Collection
        model Fog::OpenStack::Compute::VolumeAttachment

        def get(server_id)
          if server_id
            puts service.list_volume_attachments(server_id).body
            load(service.list_volume_attachments(server_id).body['volumeAttachments'])
          end
        rescue Fog::OpenStack::Compute::NotFound
          nil
        end
      end
    end
  end
end
