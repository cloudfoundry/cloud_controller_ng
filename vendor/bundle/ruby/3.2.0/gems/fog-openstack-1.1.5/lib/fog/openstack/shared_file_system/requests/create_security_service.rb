module Fog
  module OpenStack
    class SharedFileSystem
      class Real
        def create_security_service(type, name, options = {})
          data = {
            'type' => type,
            'name' => name
          }

          vanilla_options = [
            :description, :dns_ip, :user, :password, :domain, :server
          ]

          vanilla_options.select { |o| options[o] }.each do |key|
            data[key] = options[key]
          end

          request(
            :body    => Fog::JSON.encode('security_service' => data),
            :expects => 200,
            :method  => 'POST',
            :path    => 'security-services'
          )
        end
      end

      class Mock
        def create_security_service(type, name, options = {})
          # stringify keys
          options = Hash[options.map { |k, v| [k.to_s, v] }]

          response = Excon::Response.new
          response.status = 200

          security_service = data[:security_services_detail].first.dup

          security_service['type'] = type
          security_service['name'] = name

          response.body = {'security_service' => security_service.merge(options)}
          response
        end
      end
    end
  end
end
