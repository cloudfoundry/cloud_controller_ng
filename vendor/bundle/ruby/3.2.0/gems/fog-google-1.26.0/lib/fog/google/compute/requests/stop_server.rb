module Fog
  module Google
    class Compute
      class Mock
        def stop_server(_identity, _zone)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def stop_server(identity, zone, discard_local_ssd=false)
          @compute.stop_instance(@project, zone.split("/")[-1], identity, discard_local_ssd: discard_local_ssd)
        end
      end
    end
  end
end
