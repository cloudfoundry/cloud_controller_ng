module Fog
  module Google
    class Compute
      class Mock
        def get_server(_instance, _zone)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def get_server(instance, zone)
          @compute.get_instance(@project, zone.split("/")[-1], instance)
        end
      end
    end
  end
end
