module VCAP::CloudController
  class PrivateDomainAccess < BaseAccess
    def create?(private_domain)
      super || private_domain.owning_organization.managers.include?(context.user)
    end

    alias_method :update?, :create?
    alias_method :delete?, :create?
  end
end
