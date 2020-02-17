module VCAP::CloudController
  class ServicePlanVisibilityDelete
    class << self
      def delete(service_plan_visibility)
        service_plan_visibility.db.transaction do
          service_plan_visibility.lock!
          service_plan_visibility.destroy
        end
      end
    end
  end
end
