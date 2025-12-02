module Fog
  module Google
    class Compute
      class Mock
        def get_route(_identity)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        # List address resources in the specified project
        #
        # @see https://cloud.google.com/compute/docs/reference/latest/routes/list
        def get_route(identity)
          @compute.get_route(@project, identity)
        end
      end
    end
  end
end
