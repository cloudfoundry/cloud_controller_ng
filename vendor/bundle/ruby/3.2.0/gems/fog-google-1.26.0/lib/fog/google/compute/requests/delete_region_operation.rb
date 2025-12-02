module Fog
  module Google
    class Compute
      class Mock
        def delete_region_operation(_region, _operation)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        # Deletes the specified region-specific Operations resource.
        # @see https://developers.google.com/compute/docs/reference/latest/regionOperations/delete
        def delete_region_operation(region, operation)
          region = region.split("/")[-1] if region.start_with? "http"
          @compute.delete_region_operation(@project, region, operation)
        end
      end
    end
  end
end
