module VCAP::CloudController::Models
  class OrganizationAccess
    include Allowy::AccessControl

    def read?(org)
      context.roles.admin? || [:users, :managers, :billing_managers, :auditors].any? do |type|
        org.send(type).include?(context.user)
      end
    end

    def update?(org)
      context.roles.admin? || (org.managers.include?(context.user) && org.status == 'active')
    end

    def create?(org)
      context.roles.admin?
    end

    def delete?(org)
      context.roles.admin?
    end
  end
end