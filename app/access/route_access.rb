module VCAP::CloudController
  class RouteAccess < BaseAccess
    def create?(route, params=nil)
      can_write_to_route(route, true)
    end

    def read?(route)
      context.queryer.can_read_route?(route.space_id)
    end

    def read_for_update?(route, params=nil)
      can_write_to_route(route, false)
    end

    def update?(route, params=nil)
      can_write_to_route(route, false)
    end

    def delete?(route)
      can_write_to_route(route, false)
    end

    def reserved?(_)
      logged_in?
    end

    def reserved_with_token?(_)
      context.queryer.can_write_globally? || has_read_scope?
    end

    def can_remove_related_object?(object, params=nil)
      read_for_update?(object, params)
    end

    def read_related_object_for_update?(object, params=nil)
      read_for_update?(object, params)
    end

    def index?(_, params=nil)
      # This can return true because the index endpoints filter objects based on user visibilities
      true
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

    def index_with_token?(_)
      # This can return true because the index endpoints filter objects based on user visibilities
      true
    end

    private

    def can_write_to_route(route, is_create=false)
      return true if context.queryer.can_write_globally?
      return false if route.in_suspended_org?
      return false if route.wildcard_host? && route.domain.shared?

      FeatureFlag.raise_unless_enabled!(:route_creation) if is_create
      context.queryer.can_write_to_active_space?(route.space_id)
    end
  end
end
