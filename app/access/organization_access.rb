module VCAP::CloudController
  class OrganizationAccess < BaseAccess
    def update?(org)
      return true if admin_user?
      org.managers.include?(context.user) && org.active?
    end
  end
end
