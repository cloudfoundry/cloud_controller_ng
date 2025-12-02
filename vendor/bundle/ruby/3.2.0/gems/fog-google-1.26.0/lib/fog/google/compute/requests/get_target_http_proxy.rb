module Fog
  module Google
    class Compute
      class Mock
        def get_target_http_proxy(_proxy_name)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def get_target_http_proxy(proxy_name)
          @compute.get_target_http_proxy(@project, proxy_name)
        end
      end
    end
  end
end
