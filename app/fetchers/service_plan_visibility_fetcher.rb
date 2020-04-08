module VCAP::CloudController
  class ServicePlanVisibilityFetcher
    def initialize(permission_queryer)
      @permission_queryer = permission_queryer
    end

    def fetch_orgs(service_plan_guids:)
      omniscient = @permission_queryer.can_read_globally?
      readable_org_guids = @permission_queryer.readable_org_guids unless omniscient

      dataset = Organization.dataset.
                join(:service_plan_visibilities, organization_id: Sequel[:organizations][:id]).
                join(:service_plans, id: Sequel[:service_plan_visibilities][:service_plan_id]).
                where { Sequel[:service_plans][:guid] =~ service_plan_guids }

      unless omniscient
        dataset = dataset.where { Sequel[:organizations][:guid] =~ readable_org_guids }
      end

      dataset.
        select_all(:organizations).
        distinct.
        order_by(:id).
        all
    end
  end
end
