module VCAP::CloudController
  class TaskAccess < BaseAccess
    def create?(task)
      super || task.space.developers.include?(context.user)
    end

    alias_method :update?, :create?
    alias_method :delete?, :create?
  end
end
