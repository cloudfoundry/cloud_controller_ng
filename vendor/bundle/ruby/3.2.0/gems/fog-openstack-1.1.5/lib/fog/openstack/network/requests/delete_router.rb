module Fog
  module OpenStack
    class Network
      class Real
        def delete_router(router_id)
          request(
            :expects => 204,
            :method  => 'DELETE',
            :path    => "routers/#{router_id}"
          )
        end
      end

      class Mock
        def delete_router(router_id)
          response = Excon::Response.new
          if list_routers.body['routers'].find { |r| r[:id] == router_id }
            data[:routers].delete(router_id)
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
