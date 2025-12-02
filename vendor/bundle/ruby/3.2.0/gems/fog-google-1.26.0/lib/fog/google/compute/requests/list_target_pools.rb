module Fog
  module Google
    class Compute
      class Mock
        def list_target_pools(_region, _opts = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def list_target_pools(region, filter: nil, max_results: nil,
                              order_by: nil, page_token: nil)
          @compute.list_target_pools(
            @project, region.split("/")[-1],
            filter: filter,
            max_results: max_results,
            order_by: order_by,
            page_token: page_token
          )
        end
      end
    end
  end
end
