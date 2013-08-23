module VCAP::CloudController::Models
  class ServicePlanAccess < BaseAccess
    def read?(service_plan)
      super || logged_in?
    end
  end
end