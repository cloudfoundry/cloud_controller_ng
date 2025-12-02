module Fog
  module Google
    class Compute
      class Mock
        def delete_target_https_proxy(_proxy_name)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def delete_target_https_proxy(proxy_name)
          @compute.delete_target_https_proxy(@project, proxy_name)
        end
      end
    end
  end
end
