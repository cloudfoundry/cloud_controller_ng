module Fog
  module Google
    class Compute
      class Mock
        def insert_network(_network_name, _opts = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def insert_network(network_name, opts = {})
          opts = opts.merge(:name => network_name)

          @compute.insert_network(
            @project,
            ::Google::Apis::ComputeV1::Network.new(**opts)
          )
        end
      end
    end
  end
end
