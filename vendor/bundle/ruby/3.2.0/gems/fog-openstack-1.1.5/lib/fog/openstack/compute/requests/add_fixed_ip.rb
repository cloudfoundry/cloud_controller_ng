module Fog
  module OpenStack
    class Compute
      class Real
        # Add an IP address on a network.
        #
        # === Parameters
        # * server_id <~String> - The ID of the server in which to add an IP to.
        # * network_id <~String> - The ID of the network the IP should be on.
        # === Returns
        # * success <~Boolean>
        def add_fixed_ip(server_id, network_id)
          body = {
            'addFixedIp' => {
              'networkId' => network_id
            }
          }
          server_action(server_id, body).status == 202
        end
      end

      class Mock
        def add_fixed_ip(_server_id, _network_id)
          true
        end
      end
    end
  end
end
