module Fog
  module OpenStack
    class Monitoring
      class Real
        def create_notification_method(options)
          request(
            :body    => Fog::JSON.encode(options),
            :expects => [201, 204],
            :method  => 'POST',
            :path    => 'notification-methods'
          )
        end
      end

      class Mock
      end
    end
  end
end
