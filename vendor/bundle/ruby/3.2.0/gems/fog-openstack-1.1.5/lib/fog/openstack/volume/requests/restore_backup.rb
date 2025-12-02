module Fog
  module OpenStack
    class Volume
      module Real
        def restore_backup(backup_id, volume_id = nil, name = nil)
          data = {'restore' => {'volume_id' => volume_id, 'name' => name}}
          request(
            :expects  => 202,
            :method   => 'POST',
            :path     => "backups/#{backup_id}/restore",
            :body     => Fog::JSON.encode(data)
          )
        end
      end
    end
  end
end
