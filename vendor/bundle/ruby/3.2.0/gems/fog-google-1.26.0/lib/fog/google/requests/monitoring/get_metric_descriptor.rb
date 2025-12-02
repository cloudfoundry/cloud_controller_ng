module Fog
  module Google
    class Monitoring
      class Real
        def get_metric_descriptor(metric_type)
          @monitoring.get_project_metric_descriptor("projects/#{@project}/metricDescriptors/#{metric_type}")
        end
      end

      class Mock
        def get_metric_descriptor(_metric_type)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
