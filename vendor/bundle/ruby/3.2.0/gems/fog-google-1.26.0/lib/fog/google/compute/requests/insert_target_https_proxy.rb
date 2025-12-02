module Fog
  module Google
    class Compute
      class Mock
        def insert_target_https_proxy(_proxy_name, _description: nil,
                                      _url_map: nil, _ssl_certificates: nil)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def insert_target_https_proxy(proxy_name, description: nil,
                                      url_map: nil, ssl_certificates: nil)
          @compute.insert_target_https_proxy(
            @project,
            ::Google::Apis::ComputeV1::TargetHttpsProxy.new(
              name: proxy_name,
              description: description,
              url_map: url_map,
              ssl_certificates: ssl_certificates
            )
          )
        end
      end
    end
  end
end
