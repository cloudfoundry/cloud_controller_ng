module Fog
  module OpenStack
    class Identity
      class V3
        class Real
          def get_policy(id)
            request(
              :expects => [200],
              :method  => 'GET',
              :path    => "policies/#{id}"
            )
          end
        end

        class Mock
          def get_policy(id)
          end
        end
      end
    end
  end
end
