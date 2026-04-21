module VCAP::CloudController
  class RoutePolicyAccess < BaseAccess
    # Space Developer of the route's space can manage route policies.
    # No bilateral requirement — destination-controlled auth only.

    def create?(route_policy, _params=nil)
      return true if admin_user?

      route = route_policy.route
      return false unless route

      space = route.space
      context.user_email && context.user.is_a?(User) &&
        space.developers.include?(context.user)
    end

    def read?(route_policy)
      return true if admin_user? || admin_read_only_user? || global_auditor?

      route = route_policy.route
      return false unless route

      object_is_visible_to_user?(route_policy, context.user)
    end

    def update?(route_policy, _params=nil)
      create?(route_policy)
    end

    def delete?(route_policy)
      create?(route_policy)
    end

    def index?(_object_class, _params=nil)
      admin_user? || admin_read_only_user? || has_read_scope? || global_auditor?
    end

    def read_with_token?(_)
      admin_user? || admin_read_only_user? || has_read_scope? || global_auditor?
    end

    def create_with_token?(_)
      admin_user? || has_write_scope?
    end

    def read_for_update_with_token?(_)
      admin_user? || has_write_scope?
    end

    def can_remove_related_object_with_token?(*)
      read_for_update_with_token?(*)
    end

    def read_related_object_for_update_with_token?(*)
      read_for_update_with_token?(*)
    end

    def update_with_token?(_)
      admin_user? || has_write_scope?
    end

    def delete_with_token?(_)
      admin_user? || has_write_scope?
    end
  end
end
