module VCAP::CloudController::Models
  class ServiceInstanceAccess < BaseAccess
    def create?(service_instance)
      super || service_instance.space.developers.include?(context.user)
    end

    alias :update? :create?
    alias :delete? :create?

    def read?(service_instance)
      super || [:developers, :auditors].any? do |type|
        service_instance.space.send(type).include?(context.user)
      end
    end
  end
end