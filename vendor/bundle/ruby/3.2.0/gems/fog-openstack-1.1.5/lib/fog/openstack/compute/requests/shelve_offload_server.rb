module Fog
  module OpenStack
    class Compute
      class Real
        # Shelve Off load the server. Data and resource associations are deleted.
        #
        # === Parameters
        # * server_id <~String> - The ID of the server to be shelve off loaded
        # === Returns
        # * success <~Boolean>
        def shelve_offload_server(server_id)
          body = {'shelveOffload' => nil}
          server_action(server_id, body).status == 202
        end
      end

      class Mock
        def shelve_offload_server(_server_id)
          true
        end
      end
    end
  end
end
