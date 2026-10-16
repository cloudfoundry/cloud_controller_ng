module CloudFoundry
  module Middleware
    module Admin
      def admin?
        VCAP::CloudController::SecurityContext.admin? || VCAP::CloudController::SecurityContext.admin_read_only?
      end
    end
  end
end
