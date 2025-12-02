module Fog
  module Google
    class Compute
      class Mock
        def delete_server(_server, _zone)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def delete_server(server, zone)
          @compute.delete_instance(@project, zone.split("/")[-1], server)
        end
      end
    end
  end
end
