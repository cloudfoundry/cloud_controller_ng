module Fog
  module OpenStack
    class Identity
      class V3
        class Real
          def list_domains(options = {})
            request(
              :expects => [200],
              :method  => 'GET',
              :path    => "domains",
              :query   => options
            )
          end
        end

        class Mock
          def list_domains(options = {})
          end
        end
      end
    end
  end
end
