module Fog
  module Google
    class Compute
      class Mock
        def delete_firewall(_firewall_name)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def delete_firewall(firewall_name)
          @compute.delete_firewall(@project, firewall_name)
        end
      end
    end
  end
end
