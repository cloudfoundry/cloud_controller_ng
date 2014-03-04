module VCAP::CloudController
  class TaskAccess < BaseAccess
    def create?(task)
      super || task.space.developers.include?(context.user)
    end

    def update?(task)
      create?(task)
    end

    def delete?(task)
      create?(task)
    end
  end
end
