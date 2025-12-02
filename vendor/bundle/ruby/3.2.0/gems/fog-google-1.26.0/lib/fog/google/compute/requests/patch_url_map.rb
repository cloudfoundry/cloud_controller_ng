module Fog
  module Google
    class Compute
      class Mock
        def patch_url_map(_url_map_name, _options = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def patch_url_map(url_map_name, options = {})
          @compute.patch_url_map(
            @project, url_map_name, ::Google::Apis::ComputeV1::UrlMap.new(options)
          )
        end
      end
    end
  end
end
