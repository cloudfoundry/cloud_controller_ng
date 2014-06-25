module VCAP::CloudController
  class SecurityGroupAccess < BaseAccess
    def read?(_)
      admin_user?
    end
  end
end
