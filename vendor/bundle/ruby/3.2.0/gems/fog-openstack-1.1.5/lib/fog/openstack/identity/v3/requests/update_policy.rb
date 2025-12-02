module Fog
  module OpenStack
    class Identity
      class V3
        class Real
          def update_policy(id, policy)
            request(
              :expects => [200],
              :method  => 'PATCH',
              :path    => "policies/#{id}",
              :body    => Fog::JSON.encode(:policy => policy)
            )
          end
        end

        class Mock
        end
      end
    end
  end
end
