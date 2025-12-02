module Fog
  module Google
    class Compute
      class Mock
        def delete_zone_operation(_zone, _operation)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        # https://developers.google.com/compute/docs/reference/latest/zoneOperations

        def delete_zone_operation(zone_name, operation)
          zone_name = zone_name.split("/")[-1] if zone_name.start_with? "http"
          @compute.delete_zone_operation(@project, zone_name, operation)
        end
      end
    end
  end
end
