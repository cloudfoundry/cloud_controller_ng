module Fog
  module Google
    class Compute
      class Mock
        def list_instance_group_managers(_zone, _opts = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def list_instance_group_managers(zone, filter: nil, max_results: nil,
                                         order_by: nil, page_token: nil)
          @compute.list_instance_group_managers(
            @project, zone, filter: filter, max_results: max_results,
                            order_by: order_by, page_token: page_token)
        end
      end
    end
  end
end
