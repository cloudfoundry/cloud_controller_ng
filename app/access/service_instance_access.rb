module VCAP::CloudController
  class ServiceInstanceAccess < BaseAccess
    def create?(service_instance)
      super || service_instance.space.developers.include?(context.user)
    end

    alias_method :update?, :create?
    alias_method :delete?, :create?
  end

  class ManagedServiceInstanceAccess < ServiceInstanceAccess
  end

  class UserProvidedServiceInstanceAccess < ServiceInstanceAccess
  end
end
