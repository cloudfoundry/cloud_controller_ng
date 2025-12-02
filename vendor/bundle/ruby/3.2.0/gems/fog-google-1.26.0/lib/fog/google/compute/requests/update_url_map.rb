module Fog
  module Google
    class Compute
      class Mock
        def update_url_map(_url_map_name, _url_map = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def update_url_map(url_map_name, url_map = {})
          url_map[:host_rules] = url_map[:host_rules] || []
          url_map[:path_matchers] = url_map[:path_matchers] || []
          url_map[:tests] = url_map[:tests] || []

          @compute.update_url_map(
            @project, url_map_name,
            ::Google::Apis::ComputeV1::UrlMap.new(
              url_map.merge(name: url_map_name)
            )
          )
        end
      end
    end
  end
end
