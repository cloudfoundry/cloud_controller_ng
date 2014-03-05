module VCAP::CloudController
  class PrivateDomainAccess < BaseAccess
    def create?(private_domain)
      return super if super
      return false if private_domain.in_suspended_org?
      private_domain.owning_organization.managers.include?(context.user)
    end

    def update?(private_domain)
      create?(private_domain)
    end

    def delete?(private_domain)
      create?(private_domain)
    end
  end
end
