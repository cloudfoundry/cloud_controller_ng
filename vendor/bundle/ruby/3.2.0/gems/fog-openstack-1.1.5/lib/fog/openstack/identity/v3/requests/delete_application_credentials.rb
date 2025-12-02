module Fog
    module OpenStack
      class Identity
        class V3
          class Real
            def delete_application_credentials(application_credential_id, user_id)
              request(
                :expects => [204],
                :method  => 'DELETE',
                :path    => "users/#{user_id}/application_credentials/#{application_credential_id}",
              )
            end
          end
  
          class Mock
            def delete_application_credentials(application_credential_id, user_id)
              raise Fog::Errors::MockNotImplemented
            end
          end
        end
      end
    end
  end
  