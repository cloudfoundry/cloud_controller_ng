module VCAP::CloudController
  class UserAccess < BaseAccess
    def create?(_object, _params=nil)
      admin_user?
    end

    def read_for_update?(_object, _params=nil)
      admin_user?
    end

    def can_remove_related_object?(object, params=nil)
      read_for_update?(object, params)
    end

    def read_related_object_for_update?(object, params=nil)
      read_for_update?(object, params)
    end

    def update?(_object, _params=nil)
      admin_user?
    end

    def delete?(_object)
      admin_user?
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

    def index_with_token?(_)
      # This can return true because the index endpoints filter objects based on user visibilities
      true
    end

    def index?(_object_class, params=nil)
      return true if admin_user? || admin_read_only_user?

      # allow related enumerations for certain models
      related_model = params && params[:related_model]
      [Organization, Space].include? related_model
    end

    def read?(user)
      return true if admin_user? || admin_read_only_user?
      return false if context.user.nil?

      user.guid == context.user.guid
    end
  end
end
