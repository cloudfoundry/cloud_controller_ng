module VCAP::CloudController
  class PrivateDomainAccess < BaseAccess
    def create?(private_domain, params=nil)
      return true if admin_user?
      return false if private_domain.in_suspended_org?
      private_domain.owning_organization.managers.include?(context.user)
    end

    def read_for_update?(private_domain, params=nil)
      create?(private_domain)
    end

    def update?(private_domain, params=nil)
      create?(private_domain)
    end

    def delete?(private_domain)
      create?(private_domain)
    end
  end
end
