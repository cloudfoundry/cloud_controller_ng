module VCAP::CloudController::Models
  class OrganizationAccess
    include Allowy::AccessControl

    def update?(org)
      context.roles.admin? || (org.managers.include?(context.user) && org.status == 'active')
    end
  end
end