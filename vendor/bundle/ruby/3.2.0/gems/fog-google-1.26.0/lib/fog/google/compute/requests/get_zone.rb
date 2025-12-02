module Fog
  module Google
    class Compute
      class Mock
        def get_zone(_zone_name)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def get_zone(zone_name)
          @compute.get_zone(@project, zone_name)
        end
      end
    end
  end
end
