module Fog
  module Google
    class Compute
      class Mock
        def delete_global_forwarding_rule(_rule)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def delete_global_forwarding_rule(rule)
          @compute.delete_global_forwarding_rule(@project, rule)
        end
      end
    end
  end
end
