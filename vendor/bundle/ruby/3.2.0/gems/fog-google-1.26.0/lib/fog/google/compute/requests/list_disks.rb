module Fog
  module Google
    class Compute
      class Mock
        def list_disks(_zone_name, _opts = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        # List disk resources in the specified zone
        # https://cloud.google.com/compute/docs/reference/latest/disks/list
        #
        # @param zone_name [String] Zone to list disks from
        def list_disks(zone_name, filter: nil, max_results: nil,
                       order_by: nil, page_token: nil)
          @compute.list_disks(
            @project, zone_name,
            filter: filter, max_results: max_results,
            order_by: order_by, page_token: page_token
          )
        end
      end
    end
  end
end
