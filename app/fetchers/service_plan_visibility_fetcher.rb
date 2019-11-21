module VCAP::CloudController
  class ServicePlanVisibilityFetcher
    class << self
      def service_plans_visible_in_orgs?(service_plan_guids, readable_org_guids)
        empty = ServicePlanVisibility.dataset.
                left_join(:organizations, id: Sequel[:service_plan_visibilities][:organization_id]).
                left_join(:service_plans, id: Sequel[:service_plan_visibilities][:service_plan_id]).
                where { (Sequel[:service_plans][:guid] =~ service_plan_guids) & (Sequel[:organizations][:guid] =~ readable_org_guids) }.
                empty?

        !empty
      end
    end
  end
end
