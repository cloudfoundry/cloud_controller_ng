module Fog
  module Google
    class Compute
      class Mock
        def get_forwarding_rule(_rule, _region)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def get_forwarding_rule(rule, region)
          if region.start_with? "http"
            region = region.split("/")[-1]
          end
          @compute.get_forwarding_rule(@project, region, rule)
        end
      end
    end
  end
end
