module Fog
  module OpenStack
    class Baremetal
      class Real
        def get_port(port_id)
          request(
            :expects => [200, 204],
            :method  => 'GET',
            :path    => "ports/#{port_id}"
          )
        end
      end

      class Mock
        def get_port(_port_id)
          response = Excon::Response.new
          response.status = [200, 204][rand(2)]
          response.body = data[:ports].first
          response
        end
      end
    end
  end
end
