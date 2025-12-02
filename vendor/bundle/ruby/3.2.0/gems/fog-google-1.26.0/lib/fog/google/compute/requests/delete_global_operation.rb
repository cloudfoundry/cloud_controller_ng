module Fog
  module Google
    class Compute
      class Mock
        def delete_global_operation(_operation)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        # @see https://developers.google.com/compute/docs/reference/latest/globalOperations/delete
        def delete_global_operation(operation)
          @compute.delete_global_operation(@project, operation)
        end
      end
    end
  end
end
