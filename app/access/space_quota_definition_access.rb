module VCAP::CloudController
  class SpaceQuotaDefinitionAccess < BaseAccess
    def can_remove_related_object?(object, params=nil)
      read_for_update?(object, params)
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

    def create?(space_quota_definition, params=nil)
      return true if admin_user?
      return false if space_quota_definition.organization.suspended?

      space_quota_definition.organization.managers.include?(context.user)
    end

    def read_for_update?(space_quota_definition, params=nil)
      create?(space_quota_definition)
    end

    def update?(space_quota_definition, params=nil)
      create?(space_quota_definition)
    end

    def delete?(space_quota_definition, params=nil)
      create?(space_quota_definition)
    end

    def read?(space_quota_definition, *_)
      context.admin_override || (
        !context.user.nil? && (
          (context.user.managed_organizations.include? space_quota_definition.organization) ||
          !(context.user.managed_spaces & space_quota_definition.spaces).empty? ||
          !(context.user.audited_spaces & space_quota_definition.spaces).empty? ||
          !(context.user.spaces & space_quota_definition.spaces).empty?
        )
      )
    end
  end
end
