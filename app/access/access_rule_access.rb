module VCAP::CloudController
  class AccessRuleAccess < BaseAccess
    # Space Developer of the route's space can manage access rules.
    # No bilateral requirement — destination-controlled auth only.

    def create?(access_rule, _params=nil)
      return true if admin_user?

      route = access_rule.route
      return false unless route

      space = route.space
      context.user_email && context.user.is_a?(User) &&
        space.developers.include?(context.user)
    end

    def read?(access_rule)
      return true if admin_user? || admin_read_only_user? || global_auditor?

      route = access_rule.route
      return false unless route

      object_is_visible_to_user?(access_rule, context.user)
    end

    def update?(access_rule, _params=nil)
      create?(access_rule)
    end

    def delete?(access_rule)
      create?(access_rule)
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

    def can_remove_related_object_with_token?(*args)
      read_for_update_with_token?(*args)
    end

    def read_related_object_for_update_with_token?(*args)
      read_for_update_with_token?(*args)
    end

    def update_with_token?(_)
      admin_user? || has_write_scope?
    end

    def delete_with_token?(_)
      admin_user? || has_write_scope?
    end
  end
end
