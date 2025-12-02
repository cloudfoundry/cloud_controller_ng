module Fog
  module OpenStack
    class KeyManager
      class Real
        def list_secrets(options = {})
          request(
            :expects => [200],
            :method  => 'GET',
            :path    => 'secrets',
            :query   => options
          )
        end
      end

      class Mock
      end
    end
  end
end
