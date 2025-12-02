module Fog
  module OpenStack
    class Identity
      class V3
        class Real
          def list_user_projects(user_id, options = {})
            request(
              :expects => [200],
              :method  => 'GET',
              :path    => "users/#{user_id}/projects",
              :query   => options
            )
          end
        end

        class Mock
          def list_user_projects
          end
        end
      end
    end
  end
end
