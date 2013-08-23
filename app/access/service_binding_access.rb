module VCAP::CloudController::Models
  class ServiceBindingAccess < BaseAccess
    def create?(service_binding)
      super ||
        service_binding.app.space.developers.include?(context.user)
    end

    def read?(service_binding)
      super ||
        service_binding.app.space.developers.include?(context.user) ||
        service_binding.app.space.auditors.include?(context.user)
    end

    alias :delete? :create?
  end
end