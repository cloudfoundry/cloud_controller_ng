module VCAP::CloudController
  class DomainAccess < BaseAccess
    def create?(domain)
      super || (domain.owning_organization && domain.owning_organization.managers.include?(context.user))
    end

    alias :update? :create?
    alias :delete? :create?
  end
end
