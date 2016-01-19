module VCAP::CloudController
  class TaskDelete
    def delete(tasks)
      tasks.each(&:destroy)
    end
  end
end
