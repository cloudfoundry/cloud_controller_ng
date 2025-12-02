module Fog
  module OpenStack
    class Volume
      module Real
        def replace_metadata(volume_id, metadata = {})
          data = {
            'metadata' => metadata
          }

          request(
            :body    => Fog::JSON.encode(data),
            :expects => [200],
            :method  => 'PUT',
            :path    => "volumes/#{volume_id}/metadata"
          )
        end
      end
    end
  end
end
