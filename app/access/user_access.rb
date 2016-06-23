module VCAP::CloudController
  class UserAccess < BaseAccess
    def index?(object_class, params=nil)
      return true if admin_user?
      # allow related enumerations for certain models
      related_model = params && params[:related_model]
      related_model == Organization || related_model == Space
    end

    def read?(object)
      return true if admin_user?
      return false if context.user.nil?
      object.guid == context.user.guid
    end
  end
end
