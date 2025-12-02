module Fog
  module Google
    class Compute
      class Mock
        def delete_network(_network_name)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def delete_network(network_name)
          @compute.delete_network(@project, network_name)
        end
      end
    end
  end
end
