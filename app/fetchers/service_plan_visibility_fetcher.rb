module VCAP::CloudController
  class ServicePlanVisibilityFetcher
    def initialize(permission_queryer)
      @permission_queryer = permission_queryer
    end

    def fetch_orgs(service_plan_guids:)
      orgs_query(service_plan_guids: service_plan_guids).all
    end

    def any_orgs?(service_plan_guids:)
      orgs_query(service_plan_guids: service_plan_guids).any?
    end

    private

    def orgs_query(service_plan_guids:)
      dataset = Organization.dataset.
                join(:service_plan_visibilities, organization_id: :organizations__id).
                join(:service_plans, id: :service_plan_visibilities__service_plan_id).
                where(service_plans__guid: service_plan_guids)

      unless @permission_queryer.can_read_globally?
        dataset = dataset.where(organizations__guid: @permission_queryer.readable_org_guids_query)
      end

      dataset.
        select_all(:organizations).
        distinct.
        order_by(:id)
    end
  end
end
