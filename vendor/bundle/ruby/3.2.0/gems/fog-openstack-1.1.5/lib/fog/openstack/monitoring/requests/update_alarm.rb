module Fog
  module OpenStack
    class Monitoring
      class Real
        def update_alarm(id, options)
          request(
            :expects => [200],
            :method  => 'PUT',
            :path    => "alarms/#{id}",
            :body    => Fog::JSON.encode(options)
          )
        end
      end

      class Mock
      end
    end
  end
end
