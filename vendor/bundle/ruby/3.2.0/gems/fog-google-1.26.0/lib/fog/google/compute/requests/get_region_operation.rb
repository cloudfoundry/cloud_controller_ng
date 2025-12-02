module Fog
  module Google
    class Compute
      class Mock
        def get_region_operation(_region, _operation)
          raise Fog::Errors::MockNotImplemented
        end
      end

      class Real
        # Retrieves the specified region-specific Operations resource
        # @see https://developers.google.com/compute/docs/reference/latest/regionOperations/get
        def get_region_operation(region, operation)
          region = region.split("/")[-1] if region.start_with? "http"
          @compute.get_region_operation(@project, region, operation)
        end
      end
    end
  end
end
