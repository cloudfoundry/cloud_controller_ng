module VCAP::CloudController
  class ServicePlanVisibilityAccess < BaseAccess
    def index?(*_)
      admin_user?
    end
  end
end
