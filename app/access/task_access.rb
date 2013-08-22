module VCAP::CloudController::Models
  class TaskAccess < BaseAccess
    def create?(task)
      super || task.space.developers.include?(context.user)
    end

    alias :update? :create?
    alias :delete? :create?

    def read?(task)
      super || task.space.organization.managers.include?(context.user) || [:developers, :managers, :auditors].any? do |type|
        task.space.send(type).include?(context.user)
      end
    end
  end
end