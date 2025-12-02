module Fog
  module OpenStack
    class Compute
      class Real
        # Pause the server.
        #
        # === Parameters
        # * server_id <~String> - The ID of the server to pause.
        # === Returns
        # * success <~Boolean>
        def pause_server(server_id)
          body = {'pause' => nil}
          server_action(server_id, body).status == 202
        end
      end

      class Mock
        def pause_server(_server_id)
          true
        end
      end
    end
  end
end
