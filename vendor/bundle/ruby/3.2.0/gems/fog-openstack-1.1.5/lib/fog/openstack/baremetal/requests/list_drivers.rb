module Fog
  module OpenStack
    class Baremetal
      class Real
        def list_drivers(options = {})
          request(
            :expects => [200, 204],
            :method  => 'GET',
            :path    => 'drivers',
            :query   => options
          )
        end
      end

      class Mock
        def list_drivers(_options = {})
          response = Excon::Response.new
          response.status = [200, 204][rand(2)]
          response.body = {"drivers" => data[:drivers]}
          response
        end
      end
    end
  end
end
