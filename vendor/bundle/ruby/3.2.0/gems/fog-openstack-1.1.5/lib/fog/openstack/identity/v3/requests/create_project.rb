module Fog
  module OpenStack
    class Identity
      class V3
        class Real
          def create_project(project)
            request(
              :expects => [201],
              :method  => 'POST',
              :path    => "projects",
              :body    => Fog::JSON.encode(:project => project)
            )
          end
        end

        class Mock
        end
      end
    end
  end
end
