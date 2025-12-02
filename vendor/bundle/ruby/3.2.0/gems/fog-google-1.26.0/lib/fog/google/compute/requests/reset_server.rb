module Fog
  module Google
    class Compute
      class Mock
        def reset_server(_identity, _zone)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def reset_server(identity, zone)
          @compute.reset_instance(@project, zone.split("/")[-1], identity)
        end
      end
    end
  end
end
