module Fog
  module OpenStack
    class Compute
      class Real
        # Shelve the server.
        #
        # === Parameters
        # * server_id <~String> - The ID of the server to be shelved
        # === Returns
        # * success <~Boolean>
        def shelve_server(server_id)
          body = {'shelve' => nil}
          server_action(server_id, body).status == 202
        end
      end

      class Mock
        def shelve_server(_server_id)
          true
        end
      end
    end
  end
end
