module Fog
    module OpenStack
      class Identity
        class V3
          class Real
            def get_application_credentials(id, user_id)
              request(
                :expects => [200],
                :method  => 'GET',
                :path    => "users/#{user_id}/application_credentials/#{id}",
              )
            end
          end
  
          class Mock
            def get_application_credentials(id, user_id)
              raise Fog::Errors::MockNotImplemented
            end
          end
        end
      end
    end
  end
  