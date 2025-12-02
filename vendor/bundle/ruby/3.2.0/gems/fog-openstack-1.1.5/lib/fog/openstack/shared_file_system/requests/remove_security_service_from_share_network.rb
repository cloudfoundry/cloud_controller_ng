module Fog
  module OpenStack
    class SharedFileSystem
      class Real
        def remove_security_service_from_share_network(security_service_id, share_network_id)
          action = {
            'remove_security_service' => {
              'security_service_id' => security_service_id
            }
          }
          share_network_action(share_network_id, action)
        end
      end

      class Mock
        def remove_security_service_from_share_network(_security_service_id, share_network_id)
          response = Excon::Response.new
          response.status = 200

          share_net = data[:share_network_updated] || data[:share_networks].first
          share_net['id'] = share_network_id
          response.body = {'share_network' => share_net}
          response
        end
      end
    end
  end
end
