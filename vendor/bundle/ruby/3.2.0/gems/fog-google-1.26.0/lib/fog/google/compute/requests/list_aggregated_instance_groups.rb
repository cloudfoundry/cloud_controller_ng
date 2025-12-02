module Fog
  module Google
    class Compute
      class Mock
        def list_aggregated_instance_groups(_options = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def list_aggregated_instance_groups(options = {})
          @compute.list_aggregated_instance_groups(@project, **options)
        end
      end
    end
  end
end
