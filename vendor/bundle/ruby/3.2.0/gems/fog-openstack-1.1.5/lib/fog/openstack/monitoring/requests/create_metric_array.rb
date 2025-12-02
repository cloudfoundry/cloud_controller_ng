module Fog
  module OpenStack
    class Monitoring
      class Real
        def create_metric_array(metrics_list)
          request(
            :body    => Fog::JSON.encode(metrics_list),
            :expects => [204],
            :method  => 'POST',
            :path    => 'metrics'
          )
        end
      end

      class Mock
      end
    end
  end
end
