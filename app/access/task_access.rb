module VCAP::CloudController::Models
  class TaskAccess < BaseAccess
    def create?(task)
      super || task.space.developers.include?(context.user)
    end

    alias :update? :create?
    alias :delete? :create?
  end
end
