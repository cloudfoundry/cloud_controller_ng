module VCAP::CloudController
  class UserAccess < BaseAccess
    def index?(object_class, params=nil)
      return true if admin_user? || admin_read_only_user?
      # allow related enumerations for certain models
      related_model = params && params[:related_model]
      related_model == Organization || related_model == Space
    end

    def read?(user)
      return true if admin_user? || admin_read_only_user?
      return false if context.user.nil?
      user.guid == context.user.guid
    end
  end
end
