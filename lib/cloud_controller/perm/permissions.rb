module VCAP
  module CloudController
    module Perm
      class Permissions
        def initialize(perm_client:, user_id:, issuer:, roles:)
          @perm_client = perm_client
          @user_id = user_id
          @roles = roles
          @issuer = issuer
        end

        # Taken from lib/cloud_controller/permissions.rb
        def can_read_globally?
          roles.admin? || roles.admin_read_only? || roles.global_auditor?
        end

        # Taken from lib/cloud_controller/permissions.rb
        def can_write_globally?
          roles.admin?
        end

        def can_read_from_space?(space_id, org_id)
          permissions = [
            { permission_name: 'space.developer', resource_id: space_id },
            { permission_name: 'space.manager', resource_id: space_id },
            { permission_name: 'space.auditor', resource_id: space_id },
            { permission_name: 'org.manager', resource_id: org_id },
          ]

          can_read_globally? ||
            perm_client.has_any_permission?(permissions: permissions, user_id: user_id, issuer: issuer)
        end

        private

        attr_reader :perm_client, :user_id, :roles, :issuer
      end
    end
  end
end
