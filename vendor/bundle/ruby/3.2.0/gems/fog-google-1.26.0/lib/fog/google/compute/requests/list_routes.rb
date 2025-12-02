module Fog
  module Google
    class Compute
      class Mock
        def list_routes(_options = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        # Retrieves the list of Route resources available to the specified project.
        #
        # @see https://cloud.google.com/compute/docs/reference/latest/routes/list
        def list_routes(filter: nil, max_results: nil, order_by: nil, page_token: nil)
          @compute.list_routes(
            @project,
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
