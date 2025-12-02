module Fog
  module Google
    class Compute
      class Mock
        def get_global_operation(_operation)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        # Get the updated status of a global operation
        # @see https://developers.google.com/compute/docs/reference/latest/globalOperations/get
        #
        # @param operation [Google::Apis::ComputeV1::Operation] Return value from asynchronous act
        def get_global_operation(operation)
          @compute.get_global_operation(@project, operation)
        end
      end
    end
  end
end
