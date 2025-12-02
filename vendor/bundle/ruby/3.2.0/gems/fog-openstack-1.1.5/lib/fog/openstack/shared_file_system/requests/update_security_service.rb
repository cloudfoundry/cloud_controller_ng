module Fog
  module OpenStack
    class SharedFileSystem
      class Real
        def update_security_service(id, options = {})
          request(
            :body    => Fog::JSON.encode('security_service' => options),
            :expects => 200,
            :method  => 'PUT',
            :path    => "security-services/#{id}"
          )
        end
      end

      class Mock
        def update_security_service(id, options = {})
          # stringify keys
          options = Hash[options.map { |k, v| [k.to_s, v] }]

          data[:security_service_updated]       = data[:security_services_detail].first.merge(options)
          data[:security_service_updated]['id'] = id

          response = Excon::Response.new
          response.status = 200
          response.body = {'security_service' => data[:security_service_updated]}
          response
        end
      end
    end
  end
end
