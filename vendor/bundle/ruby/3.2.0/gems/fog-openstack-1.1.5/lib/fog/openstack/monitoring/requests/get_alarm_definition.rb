module Fog
  module OpenStack
    class Monitoring
      class Real
        def get_alarm_definition(id)
          request(
            :expects => [200],
            :method  => 'GET',
            :path    => "alarm-definitions/#{id}"
          )
        end
      end

      class Mock
      end
    end
  end
end
