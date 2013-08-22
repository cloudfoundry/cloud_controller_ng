module VCAP::CloudController::Models
  class DomainAccess < BaseAccess
    def create?(domain)
      super || (domain.owning_organization && domain.owning_organization.managers.include?(context.user))
    end

    alias :update? :create?
    alias :delete? :create?

    def read?(domain)
      super ||
        (domain.owning_organization &&
          (domain.owning_organization.managers.include?(context.user) ||
            domain.owning_organization.auditors.include?(context.user) ||
            domain.spaces.any? do |space|
              [:managers, :developers, :auditors].any? do |type|
                space.send(type).include?(context.user)
              end
            end
          ))
    end
  end
end