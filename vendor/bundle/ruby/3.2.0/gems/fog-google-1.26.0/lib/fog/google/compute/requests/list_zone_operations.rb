module Fog
  module Google
    class Compute
      class Mock
        def list_zone_operations(_zone)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        # @see https://developers.google.com/compute/docs/reference/latest/zoneOperations/list
        def list_zone_operations(zone, filter: nil, max_results: nil,
                                 order_by: nil, page_token: nil)
          zone = zone.split("/")[-1] if zone.start_with? "http"
          @compute.list_zone_operations(
            @project, zone,
            :filter => filter,
            :max_results => max_results,
            :order_by => order_by,
            :page_token => page_token
          )
        end
      end
    end
  end
end
