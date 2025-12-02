module Fog
  module OpenStack
    class Baremetal
      class Real
        def get_driver(driver_name)
          request(
            :expects => [200, 204],
            :method  => 'GET',
            :path    => "drivers/#{driver_name}"
          )
        end
      end

      class Mock
        def get_driver(_driver_name)
          response = Excon::Response.new
          response.status = [200, 204][rand(2)]
          response.body = data[:drivers].first
          response
        end
      end
    end
  end
end
