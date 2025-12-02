module Fog
  module Google
    class Compute
      class Mock
        def insert_target_http_proxy(_proxy_name, _description: nil, _url_map: nil)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def insert_target_http_proxy(proxy_name, description: nil, url_map: nil)
          @compute.insert_target_http_proxy(
            @project,
            ::Google::Apis::ComputeV1::TargetHttpProxy.new(
              name: proxy_name,
              description: description,
              url_map: url_map
            )
          )
        end
      end
    end
  end
end
