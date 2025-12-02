module Fog
  module OpenStack
    class Identity
      class V3
        class Real
          def create_domain(domain)
            request(
              :expects => [201],
              :method  => 'POST',
              :path    => "domains",
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
