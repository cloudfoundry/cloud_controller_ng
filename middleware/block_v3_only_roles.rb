require 'mixins/client_ip'

module CloudFoundry
  module Middleware
    class BlockV3OnlyRoles
      def initialize(app, logger:)
        @app                   = app
        @logger                = logger
      end

      def call(env)
        if !allowed_path?(env['PATH_INFO']) && v3_only_role?
          [
            403,
            { 'Content-Type' => 'text/html' },
            'You are not authorized to perform the requested action. See section \'Space Supporter Role in V2\' https://docs.cloudfoundry.org/concepts/roles.html',
          ]
        else
          @app.call(env)
        end
      end

      private

      def v3_only_role?
        current_user = VCAP::CloudController::SecurityContext.current_user
        current_user.try(:id) && !globally_authenticated? && space_supporter_and_only_space_supporter?(current_user)
      end

      def allowed_path?(path)
        ['/v2/info', '/'].include?(path)
      end

      def globally_authenticated?
        roles.admin? || roles.admin_read_only? || roles.global_auditor?
      end

      def space_supporter_and_only_space_supporter?(current_user)
        user_roles =
          VCAP::CloudController::SpaceManager.select(Sequel.as(VCAP::CloudController::RoleTypes::SPACE_MANAGER, :type)).limit(1).where(user_id: current_user.id).
          union(VCAP::CloudController::SpaceDeveloper.select(Sequel.as(VCAP::CloudController::RoleTypes::SPACE_DEVELOPER, :type)).limit(1).where(user_id: current_user.id)).
          union(VCAP::CloudController::SpaceAuditor.select(Sequel.as(VCAP::CloudController::RoleTypes::SPACE_AUDITOR, :type)).limit(1).where(user_id: current_user.id)).
          union(VCAP::CloudController::SpaceSupporter.select(Sequel.as(VCAP::CloudController::RoleTypes::SPACE_SUPPORTER, :type)).limit(1).where(user_id: current_user.id)).
          union(VCAP::CloudController::OrganizationManager.select(Sequel.as(VCAP::CloudController::RoleTypes::ORGANIZATION_MANAGER,
                                                                            :type)).limit(1).where(user_id: current_user.id)).
          union(VCAP::CloudController::OrganizationBillingManager.select(Sequel.as(VCAP::CloudController::RoleTypes::ORGANIZATION_BILLING_MANAGER,
                                                                                   :type)).limit(1).where(user_id: current_user.id)).
          union(VCAP::CloudController::OrganizationAuditor.select(Sequel.as(VCAP::CloudController::RoleTypes::ORGANIZATION_AUDITOR,
                                                                            :type)).limit(1).where(user_id: current_user.id)).
          all

        user_roles.count == 1 && user_roles[0][:type] == 'space_supporter'
      end

      def roles
        VCAP::CloudController::SecurityContext.roles
      end
    end
  end
end
