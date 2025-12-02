module Fog
  module Google
    class Compute
      class Mock
        def get_project(_identity)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def get_project(identity)
          @compute.get_project(identity)
        end
      end
    end
  end
end
