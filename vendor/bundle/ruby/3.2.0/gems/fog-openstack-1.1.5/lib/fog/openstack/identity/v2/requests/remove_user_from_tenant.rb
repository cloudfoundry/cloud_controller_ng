module Fog
  module OpenStack
    class Identity
      class V2
        class Real
          def remove_user_from_tenant(tenant_id, user_id, role_id)
            request(
              :expects => [200, 204],
              :method  => 'DELETE',
              :path    => "/tenants/#{tenant_id}/users/#{user_id}/roles/OS-KSADM/#{role_id}"
            )
          end
        end

        class Mock
          def remove_user_from_tenant(tenant_id, user_id, role_id)
          end
        end
      end
    end
  end
end
