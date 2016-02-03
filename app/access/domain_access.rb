module VCAP::CloudController
  class DomainAccess < BaseAccess
    def create?(domain, params=nil)
      return true if admin_user?
      actual_access(domain).create?(domain, params)
    end

    def read_for_update?(domain, params=nil)
      actual_access(domain).read_for_update?(domain, params)
    end

    def update?(domain, params=nil)
      actual_access(domain).update?(domain, params)
    end

    def delete?(domain)
      actual_access(domain).delete?(domain)
    end

    def read?(domain)
      actual_access(domain).read?(domain)
    end

    private

    def actual_access(domain)
      if domain.owning_organization
        PrivateDomainAccess.new(context)
      else
        SharedDomainAccess.new(context)
      end
    end
  end
end
