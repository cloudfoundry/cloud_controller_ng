module Fog
    module OpenStack
      class Identity
        class V3
          class Real
            def list_application_credentials(user_id)
              request(
                :expects => [200],
                :method  => 'GET',
                :path    => "users/#{user_id}/application_credentials",
              )
            end
          end
  
          class Mock
            def list_application_credentials(user_id)
              raise Fog::Errors::MockNotImplemented
            end
          end
        end
      end
    end
  end
