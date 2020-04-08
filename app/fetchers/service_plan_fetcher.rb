module VCAP::CloudController
  class ServicePlanFetcher
    class << self
      def fetch(service_plan_guid)
        ServicePlan.where(guid: service_plan_guid).eager(:service).first
      end
    end
  end
end
