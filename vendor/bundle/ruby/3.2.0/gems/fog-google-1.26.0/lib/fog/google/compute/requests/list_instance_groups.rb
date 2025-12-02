module Fog
  module Google
    class Compute
      class Mock
        def list_instance_groups(_zone)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def list_instance_groups(zone)
          @compute.list_instance_groups(@project, zone)
        end
      end
    end
  end
end
