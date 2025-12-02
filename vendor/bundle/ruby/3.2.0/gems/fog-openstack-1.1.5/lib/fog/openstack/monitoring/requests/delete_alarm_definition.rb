module Fog
  module OpenStack
    class Monitoring
      class Real
        def delete_alarm_definition(id)
          request(
            :expects => [204],
            :method  => 'DELETE',
            :path    => "alarm-definitions/#{id}"
          )
        end
      end

      class Mock
      end
    end
  end
end
