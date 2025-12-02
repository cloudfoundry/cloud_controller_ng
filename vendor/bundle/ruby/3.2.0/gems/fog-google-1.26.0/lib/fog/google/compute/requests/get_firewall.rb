module Fog
  module Google
    class Compute
      class Mock
        def get_firewall(_firewall_name)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def get_firewall(firewall_name)
          @compute.get_firewall(@project, firewall_name)
        end
      end
    end
  end
end
