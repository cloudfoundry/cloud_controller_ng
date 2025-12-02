module Fog
  module Google
    class Compute
      class Mock
        def delete_forwarding_rule(_rule, _region)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def delete_forwarding_rule(rule, region)
          region = region.split("/")[-1] if region.start_with? "http"
          @compute.delete_forwarding_rule(@project, region, rule)
        end
      end
    end
  end
end
