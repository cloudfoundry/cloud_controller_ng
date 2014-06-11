module VCAP::CloudController
  class AppSecurityGroupAccess < BaseAccess
    def read?(_)
      admin_user?
    end
  end
end
