module Fog
  module Google
    class Compute
      class Mock
        def delete_route(_identity)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        # Deletes the specified Route resource.
        #
        # @param identity [String] Name of the route to delete
        # @see https://cloud.google.com/compute/docs/reference/latest/routes/delete
        def delete_route(identity)
          @compute.delete_route(@project, identity)
        end
      end
    end
  end
end
