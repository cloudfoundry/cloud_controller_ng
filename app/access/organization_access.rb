module VCAP::CloudController::Models
  class OrganizationAccess < BaseAccess
    def update?(org)
      super || (org.managers.include?(context.user) && org.status == 'active')
    end
  end
end
