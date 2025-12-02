module Fog
  module OpenStack
    class SharedFileSystem
      class Real
        def share_network_action(id, options = {}, expects_status = 200)
          request(
            :body    => Fog::JSON.encode(options),
            :expects => expects_status,
            :method  => 'POST',
            :path    => "share-networks/#{id}/action"
          )
        end
      end
    end
  end
end
