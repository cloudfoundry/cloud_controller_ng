module Fog
  module OpenStack
    class SharedFileSystem
      class Real
        def get_security_service(id)
          request(
            :expects => 200,
            :method  => 'GET',
            :path    => "security-services/#{id}"
          )
        end
      end

      class Mock
        def get_security_service(id)
          response = Excon::Response.new
          response.status = 200
          security_service = data[:security_service_updated] || data[:security_services_detail].first
          security_service['id'] = id
          response.body = {'security_service' => security_service}
          response
        end
      end
    end
  end
end
