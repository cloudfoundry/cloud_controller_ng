module VCAP::CloudController
  class OrganizationAccess < BaseAccess
    def update?(org)
      super || (org.managers.include?(context.user) && org.active?)
    end
  end
end
