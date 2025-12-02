module Fog
  module OpenStack
    class SharedFileSystem
      class Real
        def list_security_services_detail(options = {})
          request(
            :expects => 200,
            :method  => 'GET',
            :path    => 'security-services/detail',
            :query   => options
          )
        end
      end

      class Mock
        def list_security_services_detail(_options = {})
          response = Excon::Response.new
          response.status = 200
          response.body = {'security_services' => data[:security_services_detail]}
          response
        end
      end
    end
  end
end
