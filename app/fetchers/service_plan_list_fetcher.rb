module VCAP::CloudController
  class ServicePlanListFetcher
    def fetch_public
      ServicePlan.dataset.
        where { Sequel[:service_plans][:public] =~ true }.
        distinct.
        select_all(:service_plans)
    end
  end
end
