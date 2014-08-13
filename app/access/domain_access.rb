module VCAP::CloudController
  class DomainAccess < BaseAccess
    def create?(domain, params=nil)
      return true if admin_user?
      domain.owning_organization && domain.owning_organization.managers.include?(context.user)
    end

    def read_for_update?(domain, params=nil)
      create?(domain, params)
    end

    def update?(domain, params=nil)
      create?(domain, params)
    end

    def delete?(domain)
      create?(domain)
    end
  end
end
