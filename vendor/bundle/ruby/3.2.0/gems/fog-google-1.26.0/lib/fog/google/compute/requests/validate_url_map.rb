module Fog
  module Google
    class Compute
      class Mock
        def validate_url_map(_url_map_name, _url_map: {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def validate_url_map(url_map_name, url_map = {})
          @compute.validate_url_map(
            @project, url_map_name,
            ::Google::Apis::ComputeV1::ValidateUrlMapsRequest.new(
              url_map: ::Google::Apis::ComputeV1::UrlMap.new(**url_map)
            )
          )
        end
      end
    end
  end
end
