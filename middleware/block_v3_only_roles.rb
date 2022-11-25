require 'mixins/client_ip'

module CloudFoundry
  module Middleware
    class BlockV3OnlyRoles
      def initialize(app, opts)
        @app                   = app
        @logger                = opts[:logger]
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
        path.match?(%r{^(/|/v2/info|/internal/v4/.*)$})
      end

      def globally_authenticated?
        roles.admin? || roles.admin_read_only? || roles.global_auditor?
      end

      def space_supporter_and_only_space_supporter?(current_user)
        return false unless current_user.org_manager_org_ids.limit(1).
                            union(current_user.org_billing_manager_org_ids.limit(1), from_self: false).
                            union(current_user.org_auditor_org_ids.limit(1), from_self: false).
                            union(current_user.space_manager_space_ids.limit(1), from_self: false).
                            union(current_user.space_auditor_space_ids.limit(1), from_self: false).
                            union(current_user.space_developer_space_ids.limit(1), from_self: false).
                            empty?

        current_user.space_supporter_space_ids.limit(1).any?
      end

      def roles
        VCAP::CloudController::SecurityContext.roles
      end
    end
  end
end
