module Fog
  module OpenStack
    class Network
      class Real
        def delete_lb_health_monitor(health_monitor_id)
          request(
            :expects => 204,
            :method  => 'DELETE',
            :path    => "lb/health_monitors/#{health_monitor_id}"
          )
        end
      end

      class Mock
        def delete_lb_health_monitor(health_monitor_id)
          response = Excon::Response.new
          if list_lb_health_monitors.body['health_monitors'].map { |r| r['id'] }.include? health_monitor_id
            data[:lb_health_monitors].delete(health_monitor_id)
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
