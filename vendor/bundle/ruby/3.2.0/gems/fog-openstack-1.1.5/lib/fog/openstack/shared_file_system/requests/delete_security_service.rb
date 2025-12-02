module Fog
  module OpenStack
    class SharedFileSystem
      class Real
        def delete_security_service(id)
          request(
            :expects => 202,
            :method  => 'DELETE',
            :path    => "security-services/#{id}"
          )
        end
      end

      class Mock
        def delete_security_service(_id)
          response = Excon::Response.new
          response.status = 202

          response
        end
      end
    end
  end
end
