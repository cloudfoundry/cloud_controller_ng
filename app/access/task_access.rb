module VCAP::CloudController::Models
  class TaskAccess
    include Allowy::AccessControl

    def create?(task)
      context.roles.admin? || task.space.developers.include?(context.user)
    end

    alias :update? :create?
    alias :delete? :create?

    def read?(task)
      context.roles.admin? || task.space.organization.managers.include?(context.user) || [:developers, :managers, :auditors].any? do |type|
        task.space.send(type).include?(context.user)
      end
    end
  end
end