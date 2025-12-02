module Fog
  module OpenStack
    class Compute
      class Real
        # Retrieve server diagnostics.
        #
        # === Parameters
        # * server_id <~String> - The ID of the server to retrieve diagnostics.
        # === Returns
        # * actions <~Array>
        def server_diagnostics(server_id)
          request(
            :method => 'GET',
            :path   => "servers/#{server_id}/diagnostics"
          )
        end
      end

      class Mock
        def server_diagnostics(server_id)
        end
      end
    end
  end
end
