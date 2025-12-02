module Fog
  module Google
    class Compute
      class Mock
        def list_disk_types(_zone, _options: {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def list_disk_types(zone, filter: nil, max_results: nil,
                            order_by: nil, page_token: nil)
          @compute.list_disk_types(
            @project, zone.split("/")[-1],
            filter: filter, max_results: max_results,
            order_by: order_by, page_token: page_token
          )
        end
      end
    end
  end
end
