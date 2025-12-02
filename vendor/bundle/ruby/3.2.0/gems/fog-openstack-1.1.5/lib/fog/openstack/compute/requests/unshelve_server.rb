module Fog
  module OpenStack
    class Compute
      class Real
        # Unshelve the server.
        #
        # === Parameters
        # * server_id <~String> - The ID of the server to be unshelved
        # === Returns
        # * success <~Boolean>
        def unshelve_server(server_id)
          body = {'unshelve' => nil}
          server_action(server_id, body).status == 202
        end
      end

      class Mock
        def unshelve_server(_server_id)
          true
        end
      end
    end
  end
end
