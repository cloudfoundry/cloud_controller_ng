module Fog
  module OpenStack
    class Compute
      class Real
        # Rescue the server.
        #
        # === Parameters
        # * server_id <~String> - The ID of the server to be rescued.
        # === Returns
        # * success <~Boolean>
        def rescue_server(server_id)
          body = {'rescue' => nil}
          server_action(server_id, body) == 202
        end
      end

      class Mock
        def rescue_server(_server_id)
          true
        end
      end
    end
  end
end
