module Fog
  module OpenStack
    class Identity
      class V3
        class Real
          def update_os_credential(id, credential)
            request(
              :expects => [200],
              :method  => 'PATCH',
              :path    => "credentials/#{id}",
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
