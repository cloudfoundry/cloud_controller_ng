module VCAP::CloudController
  class UserAccess < BaseAccess

    def index?(_)
      admin_user?
    end

    def read?(_)
      admin_user?
    end
  end
end
