module Fog
  module OpenStack
    class Identity
      class V3
        class Real
          def update_domain(id, domain)
            request(
              :expects => [200],
              :method  => 'PATCH',
              :path    => "domains/#{id}",
              :body    => Fog::JSON.encode(:domain => domain)
            )
          end
        end

        class Mock
        end
      end
    end
  end
end
