module Fog
  module OpenStack
    class Identity
      class V3
        class Real
          def delete_os_credential(id)
            request(
              :expects => [204],
              :method  => 'DELETE',
              :path    => "credentials/#{id}"
            )
          end
        end

        class Mock
        end
      end
    end
  end
end
