module Fog
  module OpenStack
    class Baremetal
      class Real
        def list_nodes_detailed(options = {})
          request(
            :expects => [200, 204],
            :method  => 'GET',
            :path    => 'nodes/detail',
            :query   => options
          )
        end
      end

      class Mock
        def list_nodes_detailed(_options = {})
          response = Excon::Response.new
          response.status = [200, 204][rand(2)]
          response.body = {"nodes" => data[:nodes]}
          response
        end
      end
    end
  end
end
