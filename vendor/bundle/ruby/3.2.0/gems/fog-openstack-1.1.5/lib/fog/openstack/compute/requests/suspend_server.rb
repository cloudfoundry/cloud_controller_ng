module Fog
  module OpenStack
    class Compute
      class Real
        # Suspend the server.
        #
        # === Parameters
        # * server_id <~String> - The ID of the server to suspend.
        # === Returns
        # * success <~Boolean>
        def suspend_server(server_id)
          body = {'suspend' => nil}
          server_action(server_id, body).status == 202
        end
      end

      class Mock
        def suspend_server(_server_id)
          true
        end
      end
    end
  end
end
