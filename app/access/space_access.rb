module VCAP::CloudController
  class SpaceAccess < BaseAccess
    def read?(object)
      return @ok_read if instance_variable_defined?(:@ok_read)
      @ok_read = (admin_user? || admin_read_only_user? || global_auditor? || object_is_visible_to_user?(object, context.user))
    end

    def read_related_object_for_update?(object, params=nil)
      read_for_update?(object, params)
    end

    def index?(object_class, params=nil)
      # This can return true because the index endpoints filter objects based on user visibilities
      true
    end

    # These methods should be called first to determine if the user's token has the appropriate scope for the operation

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

    def create?(space, params=nil)
      return true if admin_user?
      return false if space.in_suspended_org?
      space.organization.managers.include?(context.user)
    end

    def can_remove_related_object?(space, params)
      return true if admin_user?
      user_acting_on_themselves?(params) || read_for_update?(space, params)
    end

    def read_for_update?(space, params=nil)
      return true if admin_user?
      return false if space.in_suspended_org?
      space.organization.managers.include?(context.user) || space.managers.include?(context.user)
    end

    def update?(space, params=nil)
      read_for_update?(space, params)
    end

    def delete?(space)
      create?(space)
    end

    private

    def user_acting_on_themselves?(options)
      [:auditors, :developers, :managers].include?(options[:relation]) && context.user.guid == options[:related_guid]
    end
  end
end
