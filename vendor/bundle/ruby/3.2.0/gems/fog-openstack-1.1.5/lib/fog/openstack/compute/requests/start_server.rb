module Fog
  module OpenStack
    class Compute
      class Real
        # Start the server.
        #
        # === Parameters
        # * server_id <~String> - The ID of the server to be started.
        # === Returns
        # * success <~Boolean>
        def start_server(server_id)
          body = {'os-start' => nil}
          server_action(server_id, body).status == 202
        end
      end

      class Mock
        def start_server(_server_id)
          true
        end
      end
    end
  end
end
