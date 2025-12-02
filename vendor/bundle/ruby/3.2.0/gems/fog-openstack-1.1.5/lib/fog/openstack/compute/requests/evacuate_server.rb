module Fog
  module OpenStack
    class Compute
      class Real
        def evacuate_server(server_id, host = nil, on_shared_storage = nil, admin_password = nil)
          evacuate                    = {}
          evacuate['host']            = host if host

          if !microversion_newer_than?('2.13') && on_shared_storage
            evacuate['onSharedStorage'] = on_shared_storage
          end

          evacuate['adminPass']       = admin_password if admin_password
          body                        = {
            'evacuate' => evacuate
          }
          server_action(server_id, body)
        end
      end

      class Mock
        def evacuate_server(_server_id, _host, _on_shared_storage, _admin_password = nil)
          response        = Excon::Response.new
          response.status = 202
          response
        end
      end
    end
  end
end
