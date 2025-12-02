module Fog
  module OpenStack
    class Identity
      class V2
        class Real
          def delete_user(user_id)
            request(
              :expects => [200, 204],
              :method  => 'DELETE',
              :path    => "users/#{user_id}"
            )
          end
        end

        class Mock
          def delete_user(user_id)
            data[:users].delete(
              list_users.body['users'].find { |x| x['id'] == user_id }['id']
            )

            response = Excon::Response.new
            response.status = 204
            response
          rescue
            raise Fog::OpenStack::Identity::NotFound
          end
        end
      end
    end
  end
end
