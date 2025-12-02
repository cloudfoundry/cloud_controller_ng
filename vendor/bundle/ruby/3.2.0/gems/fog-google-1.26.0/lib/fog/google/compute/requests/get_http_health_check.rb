module Fog
  module Google
    class Compute
      class Mock
        def get_http_health_check(_check_name)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def get_http_health_check(check_name)
          @compute.get_http_health_check(@project, check_name)
        end
      end
    end
  end
end
