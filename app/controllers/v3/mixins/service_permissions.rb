require 'fetchers/service_plan_visibility_fetcher'
module VCAP::CloudController
  module ServicePermissions
    private

    def user_cannot_see_marketplace?
      !current_user && VCAP::CloudController::FeatureFlag.enabled?(:hide_marketplace_from_unauthenticated_users)
    end

    def visible_in_readable_orgs?(service_plans)
      return false if !current_user

      ServicePlanVisibilityFetcher.new(permission_queryer).any_orgs?(
        service_plan_guids: service_plans.map(&:guid)
      )
    end

    def writable_space_scoped?(space)
      space && space.has_developer?(current_user)
    end

    def current_user_can_write?(resource)
      permission_queryer.can_write_globally? || writable_space_scoped?(resource.service_broker.space)
    end

    def visible_space_scoped?(space)
      current_user && space && (space.has_member?(current_user) || space.has_supporter?(current_user))
    end

    def visible_to_current_user?(service: nil, plan: nil)
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
