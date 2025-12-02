module Fog
  module Google
    class Compute
      class Mock
        def get_network(_network_name)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def get_network(network_name)
          @compute.get_network(@project, network_name)
        end
      end
    end
  end
end
