module Fog
  module OpenStack
    class Identity
      class V3
        class Real
          def auth_projects(options = {})
            request(
              :expects => [200],
              :method  => 'GET',
              :path    => "auth/projects",
              :query   => options
            )
          end
        end

        class Mock
          def auth_projects
          end
        end
      end
    end
  end
end
