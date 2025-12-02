module Fog
  module OpenStack
    class Network
      class Real
        def delete_lbaas_loadbalancer(loadbalancer_id)
          request(
            :expects => 204,
            :method  => 'DELETE',
            :path    => "lbaas/loadbalancers/#{loadbalancer_id}"
          )
        end
      end

      class Mock
        def delete_lbaas_loadbalancer(loadbalancer_id)
          response = Excon::Response.new
          if list_lbaas_loadbalancers.body['loadbalancers'].map { |r| r['id'] }.include? loadbalancer_id
            data[:lbaas_loadbalancers].delete(loadbalancer_id)
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
