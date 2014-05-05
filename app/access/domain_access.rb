module VCAP::CloudController
  class DomainAccess < BaseAccess
    def create?(domain)
      return true if admin_user?
      domain.owning_organization && domain.owning_organization.managers.include?(context.user)
    end

    def update?(domain)
      create?(domain)
    end

    def delete?(domain)
      create?(domain)
    end
  end
end
