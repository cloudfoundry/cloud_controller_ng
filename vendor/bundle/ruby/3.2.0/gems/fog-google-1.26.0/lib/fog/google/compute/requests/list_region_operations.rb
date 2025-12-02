module Fog
  module Google
    class Compute
      class Mock
        def list_region_operations(_region)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        # Retrieves a list of Operation resources contained within the specified region
        # @see https://developers.google.com/compute/docs/reference/latest/regionOperations/list
        def list_region_operations(region, filter: nil, max_results: nil,
                                   order_by: nil, page_token: nil)
          region = region.split("/")[-1] if region.start_with? "http"
          @compute.list_region_operations(
            @project, region,
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
