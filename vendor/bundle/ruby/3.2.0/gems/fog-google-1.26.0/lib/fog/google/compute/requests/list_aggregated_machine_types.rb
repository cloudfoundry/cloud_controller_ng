module Fog
  module Google
    class Compute
      class Mock
        def list_aggregated_machine_types(_opts = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def list_aggregated_machine_types(filter: nil, max_results: nil,
                                          page_token: nil, order_by: nil)
          @compute.list_aggregated_machine_types(
            @project,
            filter: filter, max_results: max_results,
            page_token: page_token, order_by: order_by
          )
        end
      end
    end
  end
end
