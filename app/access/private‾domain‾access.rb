module VCAP::CloudController
  class PrivateDomainAccess < BaseAccess
    def read?(object)
      return @ok_read if instance_variable_defined?(:@ok_read)

      @ok_read = (admin_user? || admin_read_only_user? || global_auditor? || object_is_visible_to_user?(object, context.user))
    end

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

    def create?(private_domain, params=nil)
      return true if admin_user?
      return false unless update?(private_domain, params)

      FeatureFlag.raise_unless_enabled!(:private_domain_creation)
      true
    end

    def read_for_update?(private_domain, params=nil)
      update?(private_domain)
    end

    def update?(private_domain, params=nil)
      return true if admin_user?
      return false if private_domain.in_suspended_org?

      private_domain.owning_organization.managers.include?(context.user)
    end

    def delete?(private_domain)
      update?(private_domain)
    end
  end
end
