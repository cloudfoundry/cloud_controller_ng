module Fog
  module Google
    class Compute
      class Mock
        def delete_url_map(_url_map_name)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def delete_url_map(url_map_name)
          @compute.delete_url_map(@project, url_map_name)
        end
      end
    end
  end
end
