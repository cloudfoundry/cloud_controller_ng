module Fog
  module OpenStack
    class Compute
      class Real
        # Stop the server.
        #
        # === Parameters
        # * server_id <~String> - The ID of the server to be stopped.
        # === Returns
        # * success <~Boolean>
        def stop_server(server_id)
          body = {'os-stop' => nil}
          server_action(server_id, body).status == 202
        end
      end

      class Mock
        def stop_server(_server_id)
          true
        end
      end
    end
  end
end
