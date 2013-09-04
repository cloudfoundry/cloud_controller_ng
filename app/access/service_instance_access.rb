module VCAP::CloudController
  class ServiceInstanceAccess < BaseAccess
    def create?(service_instance)
      super || service_instance.space.developers.include?(context.user)
    end

    alias :update? :create?
    alias :delete? :create?
  end
end
