module VCAP::CloudController
  class ServiceBindingAccess < BaseAccess
    def create?(service_binding)
      return super if super
      service_binding.app.space.developers.include?(context.user)
    end

    def delete?(service_binding)
      create?(service_binding)
    end
  end
end
