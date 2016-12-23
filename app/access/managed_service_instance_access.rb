module VCAP::CloudController
  class ManagedServiceInstanceAccess < ServiceInstanceAccess
    def allowed?(service_instance)
      return true if admin_user?
      ServicePlan.user_visible(context.user, admin_user?).filter(guid: service_instance.service_plan.guid).count.positive?
    end
  end
end
