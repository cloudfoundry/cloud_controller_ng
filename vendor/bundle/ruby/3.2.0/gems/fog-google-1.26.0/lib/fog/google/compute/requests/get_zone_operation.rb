module Fog
  module Google
    class Compute
      class Mock
        def get_zone_operation(_zone_name, _operation)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        # Get the updated status of a zone operation
        # @see https://developers.google.com/compute/docs/reference/latest/zoneOperations/get
        #
        # @param zone_name [String] Zone the operation was peformed in
        # @param operation [Google::Apis::ComputeV1::Operation] Return value from asynchronous actions
        def get_zone_operation(zone_name, operation)
          zone_name = zone_name.split("/")[-1] if zone_name.start_with? "http"
          @compute.get_zone_operation(@project, zone_name, operation)
        end
      end
    end
  end
end
