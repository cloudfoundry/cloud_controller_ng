module Fog
  module OpenStack
    class Identity
      class V3
        class Real
          def delete_endpoint(id)
            request(
              :expects => [204],
              :method  => 'DELETE',
              :path    => "endpoints/#{id}"
            )
          end
        end

        class Mock
        end
      end
    end
  end
end
