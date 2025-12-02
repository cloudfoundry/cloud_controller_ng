module Fog
  module OpenStack
    class KeyManager
      class Real
        def get_secret_metadata(uuid)
          request(
            :expects => [200],
            :method  => 'GET',
            :path    => "secrets/#{uuid}/metadata",
          )
        end
      end

      class Mock
      end
    end
  end
end
