module VCAP::CloudController::Models
  class OrganizationAccess < BaseAccess
    def read?(org)
      super || [:users, :managers, :billing_managers, :auditors].any? do |type|
        org.send(type).include?(context.user)
      end
    end

    def update?(org)
      super || (org.managers.include?(context.user) && org.status == 'active')
    end
  end
end