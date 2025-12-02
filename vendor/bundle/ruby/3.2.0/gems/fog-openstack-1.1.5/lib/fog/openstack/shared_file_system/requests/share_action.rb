module Fog
  module OpenStack
    class SharedFileSystem
      class Real
        def share_action(id, options = {}, expects_status = 202)
          request(
            :body    => Fog::JSON.encode(options),
            :expects => expects_status,
            :method  => 'POST',
            :path    => "shares/#{id}/action"
          )
        end
      end
    end
  end
end
