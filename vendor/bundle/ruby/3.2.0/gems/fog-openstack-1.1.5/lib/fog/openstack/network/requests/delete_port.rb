module Fog
  module OpenStack
    class Network
      class Real
        def delete_port(port_id)
          request(
            :expects => 204,
            :method  => 'DELETE',
            :path    => "ports/#{port_id}"
          )
        end
      end

      class Mock
        def delete_port(port_id)
          response = Excon::Response.new
          if list_ports.body['ports'].map { |r| r['id'] }.include? port_id
            data[:ports].delete(port_id)
            response.status = 204
            response
          else
            raise Fog::OpenStack::Network::NotFound
          end
        end
      end
    end
  end
end
