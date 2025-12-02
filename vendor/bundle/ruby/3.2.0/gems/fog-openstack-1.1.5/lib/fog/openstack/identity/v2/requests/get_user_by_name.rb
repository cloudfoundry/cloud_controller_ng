module Fog
  module OpenStack
    class Identity
      class V2
        class Real
          def get_user_by_name(name)
            request(
              :expects => [200, 203],
              :method  => 'GET',
              :path    => "users?name=#{name}"
            )
          end
        end

        class Mock
          def get_user_by_name(name)
            response = Excon::Response.new
            response.status = 200
            user = data[:users].values.select { |u| u['name'] == name }[0]
            response.body = {
              'user' => user
            }
            response
          end
        end
      end
    end
  end
end
