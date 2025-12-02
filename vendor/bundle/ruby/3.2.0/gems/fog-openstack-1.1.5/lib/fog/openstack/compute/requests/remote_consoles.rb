module Fog
  module OpenStack
    class Compute
      class Real
        # Get a vnc console for an instance.
        # For microversion >= 2.6
        #
        # === Parameters
        # * server_id <~String> - The ID of the server.
        # * protocol <~String> - The protocol of remote console. The valid values are vnc, spice, rdp, serial and mks.
        #   The protocol mks is added since Microversion 2.8.
        # * type <~String> - The type of remote console. The valid values are novnc, xvpvnc, rdp-html5, spice-html5,
        #   serial, and webmks. The type webmks is added since Microversion 2.8.
        # === Returns
        # * response <~Excon::Response>:
        #   * body <~Hash>:
        #     * url <~String>
        #     * type <~String>
        #     * protocol <~String>
        def remote_consoles(server_id, protocol, type)
          if microversion_newer_than?('2.6')
            body = {
              'remote_console' => {
                'protocol' => protocol, 'type' => type
              }
            }

            request(
              :body    => Fog::JSON.encode(body),
              :expects => 200,
              :method  => 'POST',
              :path    => "servers/#{server_id}/remote-consoles"
            )
          end
        end
      end

      class Mock
        def remote_consoles(_server_id, _protocol, _type)
          response = Excon::Response.new
          response.status = 200
          response.body = {
            "remote_console" => {
              "url"      => "http://192.168.27.100:6080/vnc_auto.html?token=e629bcbf-6f9e-4276-9ea1-d6eb0e618da5",
              "type"     => "novnc",
              "protocol" => "vnc"
            }
          }
          response
        end
      end
    end
  end
end
