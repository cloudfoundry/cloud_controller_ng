module Fog
  module Google
    class Compute
      class Mock
        def delete_http_health_check(_check_name)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def delete_http_health_check(check_name)
          @compute.delete_http_health_check(@project, check_name)
        end
      end
    end
  end
end
