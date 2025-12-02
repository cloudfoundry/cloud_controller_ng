module Fog
  module OpenStack
    class Identity
      class V3
        class Real
          def delete_service(id)
            request(
              :expects => [204],
              :method  => 'DELETE',
              :path    => "services/#{id}"
            )
          end
        end

        class Mock
        end
      end
    end
  end
end
