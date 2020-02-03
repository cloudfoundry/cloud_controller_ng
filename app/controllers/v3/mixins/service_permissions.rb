require 'fetchers/service_plan_visibility_fetcher'
module VCAP::CloudController
  module ServicePermissions
    private

    def user_cannot_see_marketplace?
      !current_user && VCAP::CloudController::FeatureFlag.enabled?(:hide_marketplace_from_unauthenticated_users)
    end

    def visible_in_readable_orgs?(service_plans)
      return false if !current_user

      ServicePlanVisibilityFetcher.service_plans_visible_in_orgs?(service_plans.map(&:guid), permission_queryer.readable_org_guids)
    end

    def visible_space_scoped?(space)
      current_user && space && space.has_member?(current_user)
    end

    def visible_to_current_user?(service:, plan: nil)
      if service
        space = service.service_broker.space
        plans = service.service_plans
        resource = service
      else
        space = plan.service.service_broker.space
        plans = [plan]
        resource = plan
      end
      permission_queryer.can_read_globally? || resource.public? || visible_in_readable_orgs?(plans) || visible_space_scoped?(space)
    end
  end

  def not_authenticated!
    raise CloudController::Errors::NotAuthenticated
  end
end
