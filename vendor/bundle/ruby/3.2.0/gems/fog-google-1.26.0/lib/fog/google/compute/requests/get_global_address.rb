module Fog
  module Google
    class Compute
      class Mock
        def get_global_address(_address_name)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def get_global_address(address_name)
          @compute.get_global_address(@project, address_name)
        end
      end
    end
  end
end
