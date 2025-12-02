module Fog
  module OpenStack
    class Volume
      module Mock
        def update_volume(volume_id, data = {})
          response        = Excon::Response.new
          response.status = 200
          response.body   = {'volume' => data.merge('id' => volume_id)}
          response
        end
      end
    end
  end
end
