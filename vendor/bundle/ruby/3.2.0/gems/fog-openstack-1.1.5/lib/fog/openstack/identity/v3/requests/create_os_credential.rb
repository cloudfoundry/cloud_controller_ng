module Fog
  module OpenStack
    class Identity
      class V3
        class Real
          def create_os_credential(credential)
            request(
              :expects => [201],
              :method  => 'POST',
              :path    => "credentials",
              :body    => Fog::JSON.encode(:credential => credential)
            )
          end
        end

        class Mock
        end
      end
    end
  end
end
