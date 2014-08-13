module VCAP::CloudController
  class SecurityGroupAccess < BaseAccess
    def read?(_)
      admin_user?
    end

    def index?(_)
      admin_user?
    end
  end
end
