module Fog
  module OpenStack
    class Compute
      class Real
        # Unpause the server.
        #
        # === Parameters
        # * server_id <~String> - The ID of the server to unpause.
        # === Returns
        # * success <~Boolean>
        def unpause_server(server_id)
          body = {'unpause' => nil}
          server_action(server_id, body).status == 202
        end
      end

      class Mock
        def unpause_server(_server_id)
          true
        end
      end
    end
  end
end
