module VCAP::CloudController
  class ServicePlanAccess < BaseAccess
    def object_is_visible_to_user?(service_plan, user)
      VCAP::CloudController::ServicePlan.user_visible(user, false, :read).where(guid: service_plan.guid).count > 0
    end
  end
end
