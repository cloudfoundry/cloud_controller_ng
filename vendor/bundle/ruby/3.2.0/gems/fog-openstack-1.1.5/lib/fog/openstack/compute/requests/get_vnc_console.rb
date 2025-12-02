module Fog
  module OpenStack
    class Compute
      class Real
        # Get a vnc console for an instance.
        # For microversion < 2.6 as it has been replaced with remote-consoles
        #
        # === Parameters
        # * server_id <~String> - The ID of the server.
        # * console_type <~String> - Type of vnc console to get ('novnc' or 'xvpvnc').
        # === Returns
        # * response <~Excon::Response>:
        #   * body <~Hash>:
        #     * url <~String>
        #     * type <~String>
        def get_vnc_console(server_id, console_type)
          fixed_microversion = nil
          if microversion_newer_than?('2.5')
            fixed_microversion = @microversion
            @microversion = '2.5'
          end

          body = {
            'os-getVNCConsole' => {
              'type' => console_type
            }
          }
          result = server_action(server_id, body)
          @microversion = fixed_microversion if fixed_microversion
          result
        end
      end

      class Mock
        def get_vnc_console(_server_id, _console_type)
          response = Excon::Response.new
          response.status = 200
          response.body = {
            "console" => {
              "url"  => "http://192.168.27.100:6080/vnc_auto.html?token=c3606020-d1b7-445d-a88f-f7af48dd6a20",
              "type" => "novnc"
            }
          }
          response
        end
      end
    end
  end
end
