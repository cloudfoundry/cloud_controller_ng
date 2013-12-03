module VCAP::CloudController
  class PrivateDomainAccess < BaseAccess
    def create?(private_domain)
      super || private_domain.owning_organization.managers.include?(context.user)
    end

    alias :update? :create?
    alias :delete? :create?
  end
end
