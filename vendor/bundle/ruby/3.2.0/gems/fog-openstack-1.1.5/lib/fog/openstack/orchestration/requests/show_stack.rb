module Fog
    module OpenStack
      class Orchestration
        class Real
          def show_stack(id)
            request(
              :method  => 'GET',
              :path    => "stacks/#{id}",
              :expects => 200
            )
          end
        end

        class Mock
          def show_stack(_id)
            stack = data[:stack].values

            Excon::Response.new(
              :body   => {'stack' => stack},
              :status => 200
            )
          end
        end
      end
    end
  end
