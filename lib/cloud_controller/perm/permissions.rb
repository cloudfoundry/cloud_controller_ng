module VCAP
  module CloudController
    module Perm
      class Permissions
        def initialize(perm_client:, user:, roles:)
          @perm_client = perm_client
          @user = user
          @roles = roles
        end

        # Taken from lib/cloud_controller/permissions.rb
        def can_write_globally?
          roles.admin?
        end

        # Taken from lib/cloud_controller/permissions.rb
        def can_read_globally?
          roles.admin? || roles.admin_read_only? || roles.global_auditor?
        end

        private

        attr_reader :perm_client, :user, :roles
      end
    end
  end
end
