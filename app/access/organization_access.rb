module VCAP::CloudController
  class OrganizationAccess < BaseAccess
    def update?(org)
      return true if admin_user?
      return false unless has_write_scope?
      org.managers.include?(context.user) && org.active?
    end
  end
end
