module VCAP::CloudController
  class ServiceBindingAccess < BaseAccess
    def create?(service_binding)
      super ||
      space_developer?(service_binding, context.user) ||
      org_manager?(service_binding, context.user) ||
      space_manager?(service_binding, context.user)
    end
    alias :delete? :create?

    private

    def space_developer?(binding, user)
      binding.space.developers.include? user
    end

    def space_manager?(binding, user)
      binding.space.managers.include? user
    end

    def org_manager?(binding, user)
      binding.space.organization.managers.include? user
    end
  end
end
